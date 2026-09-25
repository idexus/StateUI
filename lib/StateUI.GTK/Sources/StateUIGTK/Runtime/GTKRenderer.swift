// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// The GTK runtime: the mounted tree over GTK widgets, the window around it, and the turn.
/// Design: docs/design/platforms/gtk/runtime.md#the-gtk-runtime
@MainActor
final class GTKRenderer {
    /// The one runtime of the process, made when the application is activated.
    static var shared: GTKRenderer?

    let core = CoreLink()
    let intake = PatchIntake()
    let animator = Animator()
    let stateChannels: StateChannels
    let describedMotion: DescribedMotion
    let layoutMotion: LayoutMotion
    let frameClock: GTKFrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    let reducesMotion: () -> Bool
    let displayCycle: DisplayCycle

    /// The application the windows belong to.
    let application: UnsafeMutablePointer<GtkApplication>

    /// The mounted tree; each element's GTK half is a `GTKElement`.
    private(set) lazy var tree = MountedTree(
        core: core,
        intake: intake,
        stateChannels: stateChannels,
        describedMotion: describedMotion,
        layoutMotion: layoutMotion,
        now: frameClock.now,
        reducesMotion: reducesMotion,
        makeNative: { [unowned self] element in GTKElement(element, host: self) })

    /// The turn: jobs, a pending cycle, a render, the handlers, then the acts.
    private(set) lazy var pump = Pump(
        core: core, intake: intake, tree: tree, displayCycle: displayCycle, now: frameClock.now,
        log: { GTKLog.error($0) })

    /// What performs the acts the application calls, and answers them.
    private(set) lazy var acts = GTKActPerformer(core: core)

    /// The application's ID, which the desktop knows it by.
    var applicationID: String {
        g_application_get_application_id(application.of(GApplication.self)).map { String(cString: $0) } ?? ""
    }

    /// The window the first window element shows in; nil before it says it is there.
    private(set) var window: GTKWindow?

    /// The arrangement of pages the window shows, held by its mounted element, which owns its GTK half.
    private var shownArrangementElement: MountedElement?

    /// The window told it was made.
    private weak var createdWindow: MountedElement?

    /// Whether the screen the window stands on has been told.
    private var reportedDisplay = false

    /// Whether the window's split view has been opened wide, once.
    private var openedWide = false

    /// The scrollers moving or with something to say, each given the display's frames until it has said it all.
    private var scrollers: [Int64: WeakScroller] = [:]

    private struct WeakScroller {
        weak var view: GTKScrollView?
    }

    /// The elements whose frame the tree reads, by their view's number, and whether any may have moved since
    /// they last said where they stand.
    private var frameReaders: [Int64: WeakElement] = [:]
    private var framesMoved = false

    private struct WeakElement {
        weak var element: GTKElement?
    }

    /// A runtime whose windows belong to `application`, on GLib's monotonic clock or on `clock`, with the motion
    /// `reducesMotion` allows.
    init(
        application: UnsafeMutablePointer<GtkApplication>,
        clock: (() -> Double)? = nil,
        reducesMotion: @escaping () -> Bool = { MainActor.assumeIsolated { GTKEnvironment.reducesMotion } }
    ) {
        self.application = application
        let frameClock = clock.map { GTKFrameClock(now: $0, ticksWithGTK: false) } ?? GTKFrameClock()
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
        pump.presenter = self
    }

    /// The application was activated on GLib's thread: the first time, the first drain makes it MainActor's and
    /// the host starts; after that, a second launch brings the window forward.
    /// Design: docs/design/platforms/gtk/runtime.md#starting
    nonisolated static func activated(_ application: UnsafeMutablePointer<GtkApplication>) {
        let core = CoreLink()
        _ = core.needsRender
        _ = core.runJobs()
        nonisolated(unsafe) let application = application

        MainActor.assumeIsolated {
            if let window = shared?.window {
                window.present()
            } else {
                start(application: application)
            }
        }
    }

    /// Starts the host: the application rendered whole, then the doorbell for everything after.
    @discardableResult
    static func start(application: UnsafeMutablePointer<GtkApplication>) -> GTKRenderer {
        shared?.tree.root?.leave()

        let renderer = GTKRenderer(application: application)
        shared = renderer
        renderer.show()
        GTKDoorbell.install()
        return renderer
    }

    /// Renders the application whole, connecting its scene first, told what the host stands on.
    func show() {
        GTKEnvironment.report(to: core, applicationID: applicationID)
        GTKKeptValues.restore(into: core, applicationID: applicationID)
        GTKEnvironment.watch { [weak self] in self?.environmentChanged() }
        core.connectScene()
        pump.turn()
    }

    /// The desktop's style turned dark or light: the core hears it, and renders what it changed.
    func environmentChanged() {
        GTKEnvironment.reportChanging(to: core)
        pump.turn()
    }

    /// Reports a native event and runs its handler, then a turn; one raised while a patch applies, or inside a
    /// user's transaction, waits for it.
    func dispatch(_ handler: Int32, payload: [HostValue] = []) {
        pump.dispatch(handler, payload: payload)
    }

    /// Runs `body` as one of the user's transactions: the handlers it raises run in order once it ends, and one
    /// turn then renders everything it changed.
    func performUserTransaction(_ body: () -> Void) {
        pump.performUserTransaction(body)
    }

    /// Keeps the display's frames coming for `scroller` until it stands and has said everything.
    func requestFrames(for scroller: GTKScrollView) {
        scrollers[scroller.number] = WeakScroller(view: scroller)
        displayCycle.hold()
    }

    /// Follows where `element` stands while the tree reads it, and lets it go once nothing does.
    /// Design: docs/design/platforms/gtk/layout.md#where-a-view-stands
    func follow(_ element: GTKElement, readsFrame: Bool) {
        guard let number = element.view?.number, readsFrame != (frameReaders[number] != nil) else { return }

        frameReaders[number] = readsFrame ? WeakElement(element: element) : nil
        if readsFrame { laidOut() }
    }

    /// GTK allocated a StateUI panel, or a scroller moved: whoever reads a frame says it on the display's next frame.
    func laidOut() {
        guard !frameReaders.isEmpty, !framesMoved else { return }

        framesMoved = true
        displayCycle.hold()
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

    /// Shows the first window's arrangement of pages in a GTK window - a page by itself in a frame of its own - its
    /// pages hearing that they show, and tells the window it was made, once, in its turn.
    /// Design: docs/design/platforms/gtk/runtime.md#the-window
    private func showWindow() {
        guard let element = tree.root?.first(type: .window) else { return }

        let window = self.window ?? GTKWindow(application: application)
        if self.window == nil {
            self.window = window
            frameClock.widget = window.widget
        }
        if !reportedDisplay, gtk_widget_get_realized(window.widget) != 0 {
            reportedDisplay = true
            GTKEnvironment.reportDisplay(to: core, window: window.widget)
        }
        window.setSize(width: element.value(.width)?.number, height: element.value(.height)?.number)
        window.setMinimumSize(width: element.value(.minimumWidth)?.number, height: element.value(.minimumHeight)?.number)

        let arrangement = element.children.first { GTKElement.pageTypes.contains($0.type) }
        if arrangement !== shownArrangementElement {
            let previous = shownArrangementElement
            shownArrangementElement = arrangement
            if let arrangement, GTKElement.framedTypes.contains(arrangement.type) {
                window.show(page: arrangement.gtk.view)
            } else {
                window.show(arrangement?.gtk.view)
            }
            previous?.gtk.setPagePresented(false, reason: .window)
            arrangement?.gtk.setPagePresented(true, reason: .window)
        }
        refreshChrome()

        if element !== createdWindow {
            createdWindow = element
            if let handler = element.handler(.created) { pump.handlers.enqueuePhase(handler) }
        }
    }

    /// Writes every shown page's chrome on its header bar, and names the window after the page the user sees.
    /// Design: docs/design/platforms/gtk/pages.md#the-chrome
    func refreshChrome() {
        guard let window, let element = tree.root?.first(type: .window)?.gtk else { return }

        let arrangement = shownArrangementElement?.gtk
        if let arrangement, GTKElement.framedTypes.contains(arrangement.type) {
            window.pageFrame?.show(arrangement.chrome)
        }
        arrangement?.composeChrome()
        adaptSplitViews(in: window)
        let pageTitle = arrangement?.visiblePage?.value(.title)?.string
        window.setTitle(pageTitle.flatMap { $0.isEmpty ? nil : $0 } ?? element.value(.title)?.string)
    }

    /// Collapses the window's split view where the window is narrow, and opens it wide with its sidebar shown once
    /// the window first stands - said in the next turn, as the user's.
    private func adaptSplitViews(in window: GTKWindow) {
        guard let split = shownArrangementElement?.gtk, split.type == .splitView, let view = split.view as? GTKSplitView
        else { return }

        view.adapt(in: window.widget)
        guard !openedWide else { return }
        openedWide = true
        GTKDoorbell.afterLayout { [weak split] in
            guard let split, let view = split.view as? GTKSplitView, view.openWide() else { return }
            split.sidebarChanged(to: true)
        }
    }

    /// Goes the way back the arrangement the window shows offers, as the user does - a stack's top page going;
    /// whether there was one.
    func goBack() -> Bool {
        shownArrangementElement?.gtk.goBack() ?? false
    }
}

extension GTKRenderer: TurnPresenter {
    func presentRendered() {
        showWindow()
    }

    func perform(_ call: HostActCall) {
        acts.perform(call, in: tree, window: window, applicationID: applicationID)
    }
}

extension GTKRenderer: FramePresenter {
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
        if core.needsRender { pump.turn() }
    }
}
