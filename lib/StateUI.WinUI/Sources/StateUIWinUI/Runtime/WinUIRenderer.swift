// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// The WinUI runtime: the mounted tree over WinUI elements, the window around it, and the turn.
/// Design: docs/design/platforms/winui/runtime.md#the-winui-runtime
@MainActor
final class WinUIRenderer {
    /// The one runtime of the process, made when WinUI stands.
    static var shared: WinUIRenderer?

    let core = CoreLink()
    let intake = PatchIntake()
    let animator = Animator()
    let stateChannels: StateChannels
    let describedMotion: DescribedMotion
    let layoutMotion: LayoutMotion
    let frameClock: WinUIFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    let reducesMotion: () -> Bool
    let displayCycle: DisplayCycle

    /// The mounted tree; each element's WinUI half is a `WinUIElement`.
    private(set) lazy var tree = MountedTree(
        core: core,
        intake: intake,
        stateChannels: stateChannels,
        describedMotion: describedMotion,
        layoutMotion: layoutMotion,
        now: frameClock.now,
        reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in WinUIElement(element, host: self) })

    /// The window the first window element shows in; nil before it says it is there.
    private(set) var window: WinUIWindow?

    /// The arrangement of pages the window shows, held by its mounted element, which owns its WinUI half.
    private var shownArrangementElement: MountedElement?

    /// The window told it was made.
    private weak var createdWindow: MountedElement?

    /// Whether a turn is running; a turn asked for inside it runs once it ends.
    private var pumping = false
    private var pumpAgain = false

    /// Events raised while a patch applied, inside a user's transaction, or a page's phase, in order.
    private var queuedEvents: [QueuedEvent] = []

    /// An event waiting for its turn; a phase is rendered before the event after it runs.
    private struct QueuedEvent {
        let handler: Int32
        let payload: [HostValue]
        var isPhase = false
    }

    /// How deep the user's transactions stand; their events wait for the outermost to end.
    private var transactionDepth = 0

    /// A runtime on the performance counter or on `clock`, with the motion `reducesMotion` allows.
    init(clock: (() -> Double)? = nil, reducesMotion: @escaping () -> Bool = { !stateui_winui_animations_enabled() }) {
        let frameClock = clock.map { WinUIFrameClock(now: $0) } ?? WinUIFrameClock()
        self.frameClock = frameClock
        self.reducesMotion = reducesMotion
        stateChannels = StateChannels(animator: animator)
        describedMotion = DescribedMotion(animator: animator)
        layoutMotion = LayoutMotion(animator: animator, now: frameClock.now, reducesMotion: reducesMotion)
        displayCycle = DisplayCycle(
            core: core,
            clock: frameClock,
            animator: animator,
            stateChannels: stateChannels,
            describedMotion: describedMotion,
            layoutMotion: layoutMotion,
            reducesMotion: reducesMotion)
        frameClock.onFrame = { [weak self] now in self?.displayCycle.frame(now: now) }
        layoutMotion.onStart = { [weak self] in self?.displayCycle.hold() }
        tree.onAnimation = { [weak self] in self?.displayCycle.hold() }
        displayCycle.presenter = self
    }

    /// WinUI stands on this thread: the first drain makes it MainActor's, then the host starts.
    /// Design: docs/design/platforms/winui/runtime.md#starting
    nonisolated static func launch() {
        let core = CoreLink()
        _ = core.needsRender
        _ = core.runJobs()

        MainActor.assumeIsolated { _ = start() }
    }

    /// Starts the host: the application rendered whole, then the doorbell for everything after.
    @discardableResult
    static func start() -> WinUIRenderer {
        shared?.tree.root?.leave()

        let renderer = WinUIRenderer()
        shared = renderer
        renderer.show()
        WinUIDoorbell.install()
        return renderer
    }

    /// Renders the application whole, connecting its scene first.
    func show() {
        core.connectScene()
        pump()
    }

    /// Reports a native event and runs its handler, then a turn; one raised while a patch applies, or inside a
    /// user's transaction, waits for it.
    func dispatch(_ handler: Int32, payload: [HostValue] = []) {
        guard !intake.isApplying, transactionDepth == 0 else {
            queuedEvents.append(QueuedEvent(handler: handler, payload: payload))
            return
        }

        _ = core.dispatch(handler, payload: payload)
        pump()
    }

    /// Runs `body` as one of the user's transactions: the events it raises run in order once it ends,
    /// and one turn then renders everything it changed.
    func performUserTransaction(_ body: () -> Void) {
        transactionDepth += 1
        body()
        transactionDepth -= 1
        guard transactionDepth == 0, !intake.isApplying else { return }

        deliverQueued()
        pump()
    }

    /// Queues a page's or a window's phase: it runs in its turn, and is rendered before anything after it.
    func enqueuePhase(_ handler: Int32) {
        queuedEvents.append(QueuedEvent(handler: handler, payload: [], isPhase: true))
    }

    /// Runs the queued events in order, stopping after a phase so it is rendered first; whether any ran.
    @discardableResult
    private func deliverQueued() -> Bool {
        guard !queuedEvents.isEmpty, !intake.isApplying, transactionDepth == 0 else { return false }

        while !queuedEvents.isEmpty {
            let event = queuedEvents.removeFirst()
            _ = core.dispatch(event.handler, payload: event.payload)
            if event.isPhase { break }
        }
        return true
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
            if !created.isEmpty {
                pumpAgain = true
                return
            }
        }

        // The acts land on the interface their handler changed, so a turn that ran handlers renders again first.
        if deliverQueued() {
            pumpAgain = true
            return
        }

        for call in core.takeActCalls() {
            if let completion = call.completion {
                core.fail(completion, reason: "the WinUI host performs no act yet: \(call.act.name)")
            }
        }
    }

    /// Applies the core's render; a drifted one is asked for whole, once.
    private func render() {
        let rendered = core.render(baseline: intake.baseline)

        if !intake.take(rendered.root, generation: rendered.generation, apply: {
            tree.apply($0, complete: rendered.complete)
        }) {
            WinUILog.error("the interface drifted and is asked for whole: \(intake.lastDrift ?? "")")
            let complete = core.render(baseline: 0)
            intake.take(complete.root, generation: complete.generation, apply: {
                tree.apply($0, complete: complete.complete)
            })
        }

        displayCycle.presentStateChannels()
        showWindow()
    }

    /// Shows the first window's arrangement of pages in a WinUI window, titled as the window says, and tells
    /// the window it was made, once, in its turn.
    /// Design: docs/design/platforms/winui/runtime.md#the-window
    private func showWindow() {
        guard let element = tree.root?.first(type: .window) else { return }

        let window = self.window ?? WinUIWindow()
        self.window = window
        window.setTitle(element.value(.title)?.string)

        let arrangement = element.children.first { WinUIElement.pageTypes.contains($0.type) }
        if arrangement !== shownArrangementElement {
            shownArrangementElement = arrangement
            window.show(arrangement?.winUI.view)
        }

        if element !== createdWindow {
            createdWindow = element
            if let handler = element.handler(.created) { enqueuePhase(handler) }
        }
    }
}

extension WinUIRenderer: FramePresenter {
    var wantsFrames: Bool { false }

    func commitUserReports(now: Double) {}

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        tree.present(states: states, properties: properties)
    }

    func renderIfNeeded() {
        if core.needsRender { pump() }
    }
}
