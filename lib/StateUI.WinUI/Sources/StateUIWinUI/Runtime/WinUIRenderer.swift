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

    /// Work a layout pass left for the next turn.
    private var afterPasses: [() -> Void] = []

    /// The scrollers moving or with something to say, each given the display's frames until it has said it all.
    private var scrollers: [Int64: WeakScroller] = [:]

    private struct WeakScroller {
        weak var view: WinUIScrollView?
    }

    /// The elements whose frame the tree reads, by their view's number, and whether a pass or a scroll moved
    /// anything since they last said where they stand.
    private var frameReaders: [Int64: WeakElement] = [:]
    private var framesMoved = false

    private struct WeakElement {
        weak var element: WinUIElement?
    }

    /// A runtime on the performance counter and WinUI's frames, or on `clock` and the frames its owner gives, with
    /// the motion `reducesMotion` allows.
    init(clock: (() -> Double)? = nil, reducesMotion: @escaping () -> Bool = { !stateui_winui_animations_enabled() }) {
        let frameClock = clock.map { WinUIFrameClock(now: $0, ticksWithWinUI: false) } ?? WinUIFrameClock()
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
        stateui_winui_watch_environment()
        return renderer
    }

    /// Windows said the theme, the power or the network changed: the core hears it, and renders what it changed.
    func environmentChanged() {
        WinUIEnvironment.reportChanging(to: core)
        pump()
    }

    /// Renders the application whole, connecting its scene first.
    func show() {
        WinUIEnvironment.report(to: core)
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

    /// The number a gesture channel's state stands at; nil for no such state.
    func standingGestureValue(state: Int32) -> Double? {
        core.gestureValue(state: state)
    }

    /// Moves a gesture channel's state to `value`, and draws what that moves; whether it moved.
    @discardableResult
    func takeGestureValue(_ value: Double, state: Int32) -> Bool {
        guard core.moveGestureValue(value, state: state) else { return false }
        displayCycle.drain(now: frameClock.now())
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

        let deferred = afterPasses
        afterPasses = []
        for work in deferred { work() }

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
        refreshWindowChrome()
    }

    /// Shows the first window's arrangement of pages in a WinUI window, its pages hearing that they show, and tells
    /// the window it was made, once, in its turn.
    /// Design: docs/design/platforms/winui/runtime.md#the-window
    private func showWindow() {
        guard let element = tree.root?.first(type: .window) else { return }

        if self.window == nil {
            let window = WinUIWindow()
            self.window = window
            // The screen is known once there is a window; what reads it renders again in the next turn.
            WinUIEnvironment.reportDisplay(to: core, window: window)
            pumpAgain = true
        }
        guard let window = self.window else { return }

        let arrangement = element.children.first { WinUIElement.pageTypes.contains($0.type) }
        if arrangement !== shownArrangementElement {
            shownArrangementElement?.winUI.setPagePresented(false, reason: .window)
            shownArrangementElement = arrangement
            window.show(arrangement?.winUI.view)
            arrangement?.winUI.setPagePresented(true, reason: .window)
        }

        if element !== createdWindow {
            createdWindow = element
            if let handler = element.handler(.created) { enqueuePhase(handler) }
        }
    }
}

extension WinUIRenderer {
    /// Composes the window's one chrome again from what it shows now: the top page names the window, the stack's
    /// way back and the page's actions stand on the chrome, a split view adds the sidebar's toggle, the tabs of a
    /// tabbed view on the page path stand beneath it, and an authored title bar adds its slots.
    /// Design: docs/design/platforms/winui/pages.md#the-windows-chrome
    func refreshWindowChrome() {
        guard let window, let element = tree.root?.first(type: .window)?.winUI else { return }

        let arrangement = element.children.first { WinUIElement.pageTypes.contains($0.type) }
        arrangement?.markTabsShownByWindow()
        let titleBar = element.children.first { $0.type == .titleBar }
        let actions = arrangement?.visibleToolbarActions ?? (primary: [], overflow: [])

        var chrome = WinUIWindowChrome()
        chrome.title = arrangement?.visiblePage?.value(.title)?.string ?? element.value(.title)?.string ?? ""
        chrome.back = arrangement?.visibleBackAction
        chrome.sidebarToggle = arrangement?.visibleSidebarToggle
        chrome.leading = titleBar?.firstView(in: .leadingContent)
        chrome.center = titleBar?.firstView(in: .content) ?? arrangement?.visibleTitleView
        chrome.trailing = titleBar?.firstView(in: .trailingContent)
        chrome.actions = actions.primary
        chrome.overflow = actions.overflow
        chrome.background = arrangement?.visibleBarBackground ?? titleBar?.value(.background)
        chrome.foreground = arrangement?.visibleBarForeground ?? titleBar?.value(.barForegroundColor)
        window.apply(chrome, tabs: arrangement?.visibleWindowTabs)
    }

    /// Runs `work` in the next turn, after the layout pass under way: what a pass decides - a split view's first
    /// room - is said once WinUI has finished laying out.
    func afterPass(_ work: @escaping () -> Void) {
        afterPasses.append(work)
        stateui_winui_post_turn()
    }

    /// Goes the way back the arrangement the window shows offers - a stack's top page going; whether there was one.
    /// Design: docs/design/platforms/winui/pages.md#the-way-back
    func goBack() -> Bool {
        guard let wayBack = shownArrangementElement?.winUI.wayBack else { return false }

        wayBack()
        return true
    }

    /// Keeps the display's frames coming for `scroller` until it stands and has said everything.
    func requestFrames(for scroller: WinUIScrollView) {
        scrollers[scroller.number] = WeakScroller(view: scroller)
        displayCycle.hold()
    }

    /// Follows where `element` stands while the tree reads it, and lets it go once nothing does.
    /// Design: docs/design/platforms/winui/layout.md#where-a-view-stands
    func follow(_ element: WinUIElement, readsFrame: Bool) {
        guard let number = element.view?.number, readsFrame != (frameReaders[number] != nil) else { return }

        frameReaders[number] = readsFrame ? WeakElement(element: element) : nil
        if readsFrame { laidOut() }
    }

    /// WinUI arranged a layout, or a scroller moved: whoever reads a frame says it on the display's next frame.
    func laidOut() {
        guard !frameReaders.isEmpty, !framesMoved else { return }

        framesMoved = true
        displayCycle.hold()
    }

    /// The page's corner in the window, in DIPs: where content stands clear of the window's chrome.
    var safeAreaOrigin: Point {
        guard let content = window?.content else { return Point(x: 0, y: 0) }
        return content.origin
    }
}

extension WinUIRenderer: FramePresenter {
    var wantsFrames: Bool {
        framesMoved || scrollers.values.contains { $0.view?.wantsFrames == true }
    }

    /// Lets every moving scroller say what the frame saw it do, then every element whose frame the tree reads say
    /// where it stands, each in the order its view was made, as one user's transaction.
    func commitUserReports(now: Double) {
        guard !scrollers.isEmpty || framesMoved else { return }

        performUserTransaction {
            for number in scrollers.keys.sorted() {
                guard let view = scrollers[number]?.view else {
                    scrollers[number] = nil
                    continue
                }
                view.frame(now: now)
                if !view.wantsFrames { scrollers[number] = nil }
            }

            guard framesMoved else { return }
            framesMoved = false
            for number in frameReaders.keys.sorted() {
                guard let element = frameReaders[number]?.element else {
                    frameReaders[number] = nil
                    continue
                }
                element.reportFrame()
            }
        }
    }

    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>]) {
        tree.present(states: states, properties: properties)
    }

    func renderIfNeeded() {
        if core.needsRender { pump() }
    }
}
