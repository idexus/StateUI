// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
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

    let frameClock: AndroidFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    let reducesMotion: () -> Bool

    /// The parts every host holds alike - the core's link, the motions, the display cycle, the mounted tree and
    /// the turn - each element's Android half an `AndroidElement`.
    private(set) lazy var runtime = HostRuntime(
        clock: frameClock, reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in AndroidElement(element, host: self) },
        log: { AndroidLog.error($0) })

    private let context: JavaObject

    /// The view the page is shown in: the activity's root.
    let root: JavaObject
    private let density: Double

    /// The arrangement of pages the root shows, held by its mounted element, which owns its Android half; and
    /// whether the activity was last told there is a way back.
    private var shownArrangementElement: MountedElement?
    private var shownArrangement: AndroidElement? { shownArrangementElement?.android }
    private var handlesBack = false

    /// What the window lays over everything it shows - the inspector docked in it - held as the arrangement is.
    private var shownOverlayElement: MountedElement?

    /// The window told it was made, and whether the activity stands stopped.
    private weak var createdWindow: MountedElement?
    private var stopped = false

    /// The title the activity was last given, as the first window says it; none before any window says.
    private(set) var windowTitle: String??

    /// A runtime showing its page in `root`, on the display's clock or on `clock`,
    /// with the motion the user's settings allow or as `reducesMotion` says.
    init(
        context: JavaObject, root: JavaObject, density: Double,
        clock: (() -> Double)? = nil, reducesMotion: @escaping () -> Bool = { AndroidRenderer.animationsRemoved() }
    ) {
        self.context = context
        self.root = root
        self.density = density
        frameClock = clock.map { AndroidFrameClock(now: $0, ticksWithTheDisplay: false) } ?? AndroidFrameClock()
        self.reducesMotion = reducesMotion
        runtime.displayCycle.presenter = self
        runtime.pump.presenter = self
    }

    /// Whether the user turned the system's animations off, which StateUI reads as asking for less motion.
    /// Design: docs/design/platforms/android/motion.md#less-motion
    static func animationsRemoved() -> Bool {
        !Java.callStaticBool(JavaAPI.valueAnimator, JavaAPI.areAnimatorsEnabled)
    }

    /// Starts the host in an activity's root, then rings the doorbell for everything after its first render.
    /// An activity after the first takes over the scene the one before showed, rendered whole.
    /// Design: docs/design/platforms/android/runtime.md#a-later-activity
    @discardableResult
    static func start(context: JavaObject, root: JavaObject, density: Double) -> AndroidRenderer {
        let previous = shared
        previous?.runtime.tree.root?.leave()

        let renderer = AndroidRenderer(context: context, root: root, density: density)
        shared = renderer
        renderer.watchLayout()
        let core = renderer.runtime.core
        core.setRealization(AndroidRegistrations.registry.realization, unrealized: AndroidRealization.unrealized)
        AndroidEnvironment.report(to: core, activity: context.reference)
        if previous == nil { AndroidPersistence.restore(into: core, context: context.reference) }
        renderer.show(connectingScene: previous == nil)
        AndroidDoorbell.install { AndroidRenderer.shared?.runtime.pump.turn() }
        return renderer
    }

    /// Hears every layout pass and scroll of the root's window: where a view stands may have moved.
    /// Design: docs/design/platforms/android/layout.md#where-a-view-stands
    private func watchLayout() {
        let listener = Java.new(JavaAPI.listener, JavaAPI.newListener, .long(0))
        let observer = Java.callObject(root.reference, JavaAPI.getViewTreeObserver)!
        withExtendedLifetime(listener) {
            Java.call(observer, JavaAPI.addOnGlobalLayoutListener, .object(listener.reference))
            Java.call(observer, JavaAPI.addOnScrollChangedListener, .object(listener.reference))
        }
        Java.release(local: observer)
    }

    /// The pages the window presents over its page.
    private lazy var modals = AndroidModals(root: root, reducesMotion: reducesMotion)

    /// The acts the application calls, performed and answered.
    private lazy var acts = AndroidActPerformer(core: runtime.core, context: context, root: root)

    /// An act waiting under a ticket was answered - a dialog, a script: its caller resumes, and what that
    /// writes runs.
    func answered(ticket: Int64, accepted: Bool, words: String?) {
        acts.answered(ticket: ticket, accepted: accepted, words: words)
        runtime.pump.turn()
    }

    /// Renders the application whole, connecting its scene first where no activity has shown it.
    func show(connectingScene: Bool = true) {
        if connectingScene { runtime.core.connectScene() }
        runtime.pump.turn()
    }

    /// Reports the application's phase as the activity's lifecycle moves it, then the scene's and its window's,
    /// each rendered before the next.
    /// Design: docs/design/platforms/android/runtime.md#the-activitys-lifecycle
    func setPhase(_ phase: ApplicationPhase) {
        runtime.core.setApplicationPhase(phase)
        runtime.pump.turn()

        let tree = runtime.tree
        let resumes = stopped && phase != .background
        stopped = phase == .background
        if resumes, let handler = tree.root?.first(type: .window)?.handler(.resumed) { runtime.dispatch(handler) }

        let event: Event = switch phase {
        case .active: .activated
        case .inactive: .deactivated
        default: .stopped
        }
        for element in [tree.root?.first(type: .scene), tree.root?.first(type: .window)] {
            if let handler = element?.handler(event) { runtime.dispatch(handler) }
        }
    }

    /// The activity is finishing: its window hears it is going, then its scene.
    func destroying() {
        for type in [NodeType.window, .scene] {
            if let handler = runtime.tree.root?.first(type: type)?.handler(.destroying) { runtime.dispatch(handler) }
        }
    }

    /// The activity's configuration changed - the display turned or resized: the core is told what stands now,
    /// and the window laid out again.
    /// The zone, the clock, the battery or the network changed.
    func environmentChanged() {
        runtime.environmentChanged { AndroidEnvironment.reportChanging(to: runtime.core, context: context.reference) }
    }

    func configured() {
        runtime.environmentChanged {
            AndroidEnvironment.report(to: runtime.core, activity: context.reference)
            Java.call(root.reference, JavaAPI.requestLayout)
        }
    }

    /// The safe area's top left in the window, in points: where the page's root stands.
    var safeAreaOrigin: Point {
        let window = Java.ints([0, 0])
        Java.call(root.reference, JavaAPI.getLocationInWindow, .object(window))
        var pixels: [Int32] = [0, 0]
        pixels.withUnsafeMutableBufferPointer { Java.jni.GetIntArrayRegion(Java.env, window, 0, 2, $0.baseAddress) }
        Java.release(local: window)
        return Point(x: Double(pixels[0]) / density, y: Double(pixels[1]) / density)
    }

    /// Names the activity after the first window, and tells a window it was made, once, in its turn.
    private func showWindow() {
        guard let window = runtime.tree.root?.first(type: .window) else { return }

        let title = window.value(.title)?.string
        if windowTitle != .some(title) {
            windowTitle = .some(title)
            Java.frame {
                Java.callStatic(
                    JavaAPI.environment, JavaAPI.setWindowTitle, .object(context.reference),
                    .object(title.flatMap(Java.string)))
            }
        }
        if window !== createdWindow {
            createdWindow = window
            if let handler = window.handler(.created) { runtime.pump.handlers.enqueuePhase(handler) }
        }
    }

    /// Shows the first window's arrangement of pages in the activity's root, its pages hearing that they show,
    /// the pages its modal stack presents over it, and its overlay over them all.
    /// Design: docs/design/platforms/android/pages.md#the-windows-overlay
    private func showPage() {
        let window = runtime.tree.root?.first(type: .window)
        let arrangement = window?.children.first { AndroidElement.pageTypes.contains($0.type) }
        if arrangement !== shownArrangementElement {
            shownArrangement?.setPagePresented(false, reason: .window)
            shownArrangementElement = arrangement
            shownOverlayElement = nil
            Java.call(root.reference, JavaAPI.removeAllViews)
            if let page = shownArrangement?.view {
                page.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(page.reference), .int(-1), .int(-1))
            }
            shownArrangement?.setPagePresented(true, reason: .window)
        }

        let rose = modals.present(
            window?.children.first { $0.type == .modalStack }?.children ?? [], over: shownArrangement)
        showOverlay(window?.children.first { $0.type == .overlay }, raised: rose)
    }

    /// Lays the window's overlay over the root's pages, lifted over a page that rose after it; it takes no touch
    /// beside what it holds, which goes on to the page under it.
    private func showOverlay(_ overlay: MountedElement?, raised: Bool) {
        guard overlay === shownOverlayElement else {
            if let leaving = shownOverlayElement?.android.view {
                Java.call(root.reference, JavaAPI.removeView, .object(leaving.reference))
            }
            shownOverlayElement = overlay
            if let view = overlay?.android.view {
                view.forgetPlace()
                Java.call(root.reference, JavaAPI.addView, .object(view.reference), .int(-1), .int(-1))
            }
            return
        }
        if raised, let view = overlay?.android.view { Java.call(view.reference, JavaAPI.bringToFront) }
    }

    /// Goes the way back the page in front offers - a presented page's own, else that page going down, else
    /// the arrangement's; whether there was one.
    /// Design: docs/design/platforms/android/pages.md#the-way-back
    func goBack() -> Bool {
        if let top = modals.top {
            if let wayBack = top.wayBack {
                wayBack()
            } else {
                modals.dismissTop(over: shownArrangement)
                let window = runtime.tree.root?.first(type: .window)
                if let handler = window?.handler(.modalPopped) {
                    runtime.dispatch(handler, payload: [.number(Double(modals.count))])
                }
            }
            return true
        }
        guard let wayBack = shownArrangement?.wayBack else { return false }

        wayBack()
        return true
    }

    /// Tells the activity whether there is a way back, so the system's own back gesture knows whose it is.
    func refreshBack() {
        let handles = modals.top != nil || shownArrangement?.wayBack != nil
        guard handles != handlesBack else { return }

        handlesBack = handles
        guard Java.jni.IsInstanceOf(Java.env, context.reference, JavaAPI.activity) != 0 else { return }
        Java.call(context.reference, JavaAPI.setHandlesBack, .bool(handles))
    }
}

extension AndroidRenderer: TurnPresenter {
    /// Shows what a render changed: the activity's title, the window's pages, its sheets and its overlay, and
    /// whether there is a way back.
    func presentRendered() {
        showWindow()
        showPage()
        refreshBack()
    }

    func perform(_ call: HostActCall) {
        acts.perform(call, in: runtime.tree)
    }
}

extension AndroidRenderer: FramePresenter {
    var wantsFrames: Bool {
        runtime.frames.wantsFrames
    }

    func commitUserReports(now: Double) {
        runtime.frames.commit(now: now)
    }

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        runtime.tree.present(states: states, properties: properties)
    }

    func renderIfNeeded() {
        if runtime.core.needsRender { runtime.pump.turn() }
    }
}
