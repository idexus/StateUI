// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// The Android Views runtime: the mounted tree over Android views, the activity's window around it, and the turn.
/// Design: docs/design/platforms/android/runtime.md#the-android-views-runtime
@MainActor
final class AndroidRenderer {
    /// The one runtime of the process, made when the activity starts it.
    static var shared: AndroidRenderer?

    /// The context every view is made in: the activity.
    static var context: jobject { shared!.context.reference }

    /// Pixels per point, the display's density.
    static var density: Double { shared?.density ?? 1 }

    let core = CoreLink()
    let intake = PatchIntake()
    let animator = Animator()
    let stateChannels: StateChannels
    let describedMotion: DescribedMotion
    let layoutMotion: LayoutMotion
    let frameClock = AndroidFrameClock()
    let displayCycle: DisplayCycle

    /// The mounted tree; each element's Android half is an `AndroidElement`.
    private(set) lazy var tree = MountedTree(
        core: core,
        intake: intake,
        stateChannels: stateChannels,
        describedMotion: describedMotion,
        layoutMotion: layoutMotion,
        now: frameClock.now,
        reducesMotion: { false },
        makeNative: { [unowned self] element in AndroidElement(element, host: self) })

    private let context: JavaObject

    /// The view the page is shown in: the activity's root.
    let root: JavaObject
    private let density: Double

    /// The page's view the root shows.
    private weak var shownPage: AndroidView?

    /// Whether a turn is running; a turn asked for inside it runs once it ends.
    private var pumping = false
    private var pumpAgain = false

    /// Events raised while a patch applied, in order.
    private var queuedEvents: [(handler: Int32, payload: [HostValue])] = []

    init(context: JavaObject, root: JavaObject, density: Double) {
        self.context = context
        self.root = root
        self.density = density
        stateChannels = StateChannels(animator: animator)
        describedMotion = DescribedMotion(animator: animator)
        layoutMotion = LayoutMotion(animator: animator, now: frameClock.now, reducesMotion: { false })
        displayCycle = DisplayCycle(
            core: core,
            clock: frameClock,
            animator: animator,
            stateChannels: stateChannels,
            describedMotion: describedMotion,
            layoutMotion: layoutMotion,
            reducesMotion: { false })
        frameClock.onFrame = { [weak self] now in self?.displayCycle.frame(now: now) }
        layoutMotion.onStart = { [weak self] in self?.displayCycle.hold() }
        tree.onAnimation = { [weak self] in self?.displayCycle.hold() }
        displayCycle.presenter = self
    }

    /// Starts the host in an activity's root, then rings the doorbell for everything after its first render.
    /// An activity after the first takes over the scene the one before showed, rendered whole.
    /// Design: docs/design/platforms/android/runtime.md#a-later-activity
    @discardableResult
    static func start(context: JavaObject, root: JavaObject, density: Double) -> AndroidRenderer {
        let previous = shared
        previous?.tree.root?.leave()

        let renderer = AndroidRenderer(context: context, root: root, density: density)
        shared = renderer
        renderer.show(connectingScene: previous == nil)
        AndroidDoorbell.install { AndroidRenderer.shared?.pump() }
        return renderer
    }

    /// Renders the application whole, connecting its scene first where no activity has shown it.
    func show(connectingScene: Bool = true) {
        if connectingScene {
            core.setTheme(.light)
            core.connectScene()
        }
        pump()
    }

    /// Reports the application's phase as the activity's lifecycle moves it.
    func setPhase(_ phase: ApplicationPhase) {
        core.setApplicationPhase(phase)
        pump()
    }

    /// Reports a native event and runs its handler, then a turn; one raised while a patch applies waits for it.
    func dispatch(_ handler: Int32, payload: [HostValue] = []) {
        guard !intake.isApplying else {
            queuedEvents.append((handler, payload))
            return
        }

        _ = core.dispatch(handler, payload: payload)
        pump()
    }

    /// Reports a value the user set through a bound state.
    @discardableResult
    func report(_ value: HostStateValue, through binding: HostStateBinding) -> Bool {
        guard core.report(value, through: binding) else { return false }

        displayCycle.drain(now: frameClock.now(), reported: [binding.state: value])
        return true
    }

    /// Takes a journey the host carries at the position the user set.
    @discardableResult
    func take(_ value: [Double], through binding: HostStateBinding) -> Bool {
        guard stateChannels.take(value, through: binding) else { return false }

        displayCycle.drain(now: frameClock.now())
        return true
    }

    /// One turn: the jobs a resumed handler left, a pending cycle, a render when the core needs one, then the acts.
    /// Design: docs/design/host/runtime.md#one-turn
    func pump() {
        guard !pumping else {
            pumpAgain = true
            return
        }

        pumping = true
        repeat {
            pumpAgain = false
            turn()
        } while pumpAgain
        pumping = false
    }

    private func turn() {
        _ = core.runJobs()

        if tree.root != nil, core.cyclesPending {
            displayCycle.drain(now: frameClock.now())
        }

        if tree.root == nil || core.needsRender {
            render()

            let created = tree.root?.takeCreatedHandlers() ?? []
            for handler in created {
                _ = core.dispatch(handler)
            }

            let queued = queuedEvents
            queuedEvents.removeAll()
            for event in queued {
                _ = core.dispatch(event.handler, payload: event.payload)
            }

            // The acts land on the interface their handler changed, so a turn that ran handlers renders again first.
            if !created.isEmpty || !queued.isEmpty {
                pumpAgain = true
                return
            }
        }

        for call in core.takeActCalls() {
            if let completion = call.completion {
                core.fail(completion, reason: "the Android Views host performs no act yet")
            }
        }
    }

    /// Applies the core's render; a drifted one is asked for whole, once.
    private func render() {
        let rendered = core.render(baseline: intake.baseline)

        if !intake.take(rendered.root, generation: rendered.generation, apply: {
            tree.apply($0, complete: rendered.complete)
        }) {
            AndroidLog.error("the interface drifted and is asked for whole: \(intake.lastDrift ?? "")")
            let complete = core.render(baseline: 0)
            intake.take(complete.root, generation: complete.generation, apply: {
                tree.apply($0, complete: complete.complete)
            })
        }

        displayCycle.presentStateChannels()
        showPage()
    }

    /// Shows the first window's page in the activity's root.
    private func showPage() {
        let page = tree.root?.first(type: .window)?.first(type: .page)?.android.view
        guard page !== shownPage else { return }

        shownPage = page
        Java.call(root.reference, JavaAPI.removeAllViews)
        if let page {
            Java.call(root.reference, JavaAPI.addView, .object(page.reference), .int(-1), .int(-1))
        }
    }
}

extension AndroidRenderer: FramePresenter {
    var wantsFrames: Bool { false }

    func commitUserReports(now: Double) {}

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        tree.present(states: states, properties: properties)
    }

    func renderIfNeeded() {
        if core.needsRender { pump() }
    }
}
