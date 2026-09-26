// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The runtime's parts every host holds alike, wired once: the core's link, the patch's intake, the animator and
/// the motions, the display cycle on the host's frame clock, the mounted tree and the pump - and the roads a
/// user's change takes into them. A host adds its toolkit: its clock, its elements' native halves, and what it
/// presents at a turn's and a frame's end.
/// Design: docs/design/host/runtime.md#the-runtimes-parts
@_spi(Host) @MainActor public final class HostRuntime {
    /// The line to the core.
    public let core = CoreLink()

    /// Where the core's patches come in, in order.
    public let intake = PatchIntake()

    /// What runs every animation the host carries.
    public let animator = Animator()

    /// Each state's one motion channel, shared by every control bound to it.
    public let stateChannels: StateChannels

    /// The animations the tree describes: a property's transition.
    public let describedMotion: DescribedMotion

    /// A layout's children travelling to their new places.
    public let layoutMotion: LayoutMotion

    /// One display frame's order: the user's reports, the animations, the core's cycle, a walk, a render.
    public let displayCycle: DisplayCycle

    /// The mounted tree: one element per described node, each with its native half.
    public let tree: MountedTree

    /// The turn: jobs, a pending cycle, a render, the handlers, then the acts.
    public let pump: Pump

    /// What the display's frames serve besides the core's cycle: moving scrollers, and frames the tree reads.
    public private(set) lazy var frames = FrameFollowers(runtime: self)

    /// The host's frame clock, whose frames run the display cycle.
    public let clock: any FrameClock

    /// Whether the user asked for less motion: every animation arrives at once.
    public let reducesMotion: () -> Bool

    /// The application's phase, as the toolkit told it.
    public private(set) var lifecycle = ApplicationLifecycle()

    /// A runtime on `clock`, its elements' native halves made by `makeNative`, a drift the intake refused told to
    /// `log`.
    public init(
        clock: any FrameClock, reducesMotion: @escaping () -> Bool,
        makeNative: @escaping (MountedElement) -> any NativeElement, log: @escaping (String) -> Void
    ) {
        self.clock = clock
        self.reducesMotion = reducesMotion
        stateChannels = StateChannels(animator: animator)
        describedMotion = DescribedMotion(animator: animator)
        layoutMotion = LayoutMotion(animator: animator, now: clock.now, reducesMotion: reducesMotion)
        displayCycle = DisplayCycle(
            core: core, clock: clock, animator: animator, stateChannels: stateChannels,
            describedMotion: describedMotion, layoutMotion: layoutMotion, reducesMotion: reducesMotion)
        tree = MountedTree(
            core: core, intake: intake, stateChannels: stateChannels, describedMotion: describedMotion,
            layoutMotion: layoutMotion, now: clock.now, reducesMotion: reducesMotion, makeNative: makeNative)
        pump = Pump(core: core, intake: intake, tree: tree, displayCycle: displayCycle, now: clock.now, log: log)

        tree.tellPhase = { [weak pump] handler in pump?.handlers.enqueuePhase(handler) }
        clock.onFrame = { [weak self] now in self?.displayCycle.frame(now: now) }
        layoutMotion.onStart = { [weak self] in self?.displayCycle.hold() }
        tree.onAnimation = { [weak self] in self?.displayCycle.hold() }
    }

    /// Reports a native event and runs its handler, then a turn; one raised while a patch applies, or inside a
    /// user's transaction, waits for it.
    public func dispatch(_ handler: Int32, payload: [HostValue] = []) {
        pump.dispatch(handler, payload: payload)
    }

    /// Runs `body` as one of the user's transactions: the handlers it raises run in order once it ends, and one
    /// turn then renders everything it changed.
    public func performUserTransaction(_ body: () -> Void) {
        pump.performUserTransaction(body)
    }

    /// Reports a value the user set through a bound state, and draws what it moves; whether the state took it.
    @discardableResult
    public func report(_ value: HostStateValue, through binding: HostStateBinding) -> Bool {
        guard core.report(value, through: binding) else { return false }
        displayCycle.drain(now: clock.now(), reported: [binding.state: value])
        return true
    }

    /// Takes a journey the host carries at the position the user set; whether it took it.
    @discardableResult
    public func take(_ value: [Double], through binding: HostStateBinding) -> Bool {
        guard stateChannels.take(value, through: binding) else { return false }
        displayCycle.drain(now: clock.now())
        return true
    }

    /// The number a gesture channel's state stands at; nil for no such state.
    public func standingGestureValue(state: Int32) -> Double? {
        core.gestureValue(state: state)
    }

    /// Moves a gesture channel's state to `value`, and draws what that moves; whether it moved.
    @discardableResult
    public func takeGestureValue(_ value: Double, state: Int32) -> Bool {
        guard core.moveGestureValue(value, state: state) else { return false }
        displayCycle.drain(now: clock.now())
        return true
    }

    /// What the application stands on changed - the theme, the locale, the power, the network: `report` tells the
    /// core what stands now, the tree follows the language's direction, and a turn renders what it all changed.
    /// Design: docs/design/host/runtime.md#the-environment
    public func environmentChanged(_ report: () -> Void) {
        report()
        tree.followTheLanguagesDirection()
        pump.turn()
    }

    /// The toolkit moved the application into `phase`: the core hears it, then the scene and its window hear what
    /// it means for them (`ApplicationLifecycle.enter`), each rendered before the next - in their turn, so a toolkit
    /// telling it in the middle of one waits for it.
    /// Design: docs/design/host/runtime.md#the-applications-phase
    public func enterPhase(_ phase: ApplicationPhase) {
        guard let told = lifecycle.enter(phase) else { return }
        core.setApplicationPhase(phase)
        tell(told)
    }

    /// The application is ending: its window hears it is going, then its scene.
    public func ending() {
        tell(ApplicationLifecycle.ending)
    }

    /// The user chose tab `selected` of `tabbed`, which showed `previous`: the pages hear it, then the state the
    /// choice carries.
    /// Design: docs/design/host/pages.md#a-pages-phases
    public func tabChosen(_ tabbed: MountedElement, from previous: Int, to selected: Int) {
        let tabs = tabbed.children
        guard tabs.indices.contains(selected) else { return }

        if tabbed.isPagePresented {
            if tabs.indices.contains(previous) { tabs[previous].setPagePresented(false, reason: .appearance) }
            tabs[selected].setPagePresented(true, reason: .appearance)
        }
        tabbed.reportUserChange(.currentPage, .currentPageChanged, .number(Double(selected)), in: self) { _ in }
    }

    /// The sidebar of `split` showed or hid on screen: its page hears it, then the state its binding carries.
    public func sidebarShown(_ split: MountedElement, _ shown: Bool) {
        if split.isPagePresented { split.children.first?.setPagePresented(shown, reason: .appearance) }
        split.reportUserChange(.isSidebarVisible, .isSidebarVisibleChanged, .bool(shown), in: self) { _ in }
    }

    /// Goes `way` back in `window`: a stack's top page goes, the path told it is one shorter, or the top sheet goes,
    /// the window told how many remain.
    /// Design: docs/design/host/pages.md#the-way-back
    public func goBack(_ way: WayBack, in window: MountedElement) {
        switch way {
        case .pop(let stack):
            guard stack.children.count > 1, let handler = stack.handler(.popped) else { return }
            dispatch(handler, payload: [.number(Double(stack.children.count - 2))])
        case .dismissSheet(let remaining):
            guard let handler = window.handler(.modalPopped) else { return }
            dispatch(handler, payload: [.number(Double(remaining))])
        }
    }

    /// The user closed `window`: what that tells (`toldOnClosing`) runs in order, each rendered before the next.
    public func userClosed(_ window: MountedElement) {
        for each in Self.toldOnClosing(window) { pump.handlers.enqueuePhase(each.handler, payload: each.payload) }
        pump.turn()
    }

    /// What the user closing `window` tells, in order: the window that it is going, then its scene - that it is
    /// going too where the window is its main one, else that one of its windows closed, by the window's key.
    /// Design: docs/design/host/runtime.md#a-window-the-user-closes
    public static func toldOnClosing(_ window: MountedElement) -> [(handler: Int32, payload: [HostValue])] {
        let scene = window.enclosing(type: .scene)
        let sceneTold: (handler: Int32?, payload: [HostValue]) = window.value(.windowType) == nil
            ? (scene?.handler(.destroying), [])
            : (scene?.handler(.windowClosed), [window.id.hostValue])
        return [(window.handler(.destroying), []), sceneTold].compactMap { told in
            told.handler.map { (handler: $0, payload: told.payload) }
        }
    }

    private func tell(_ told: [ApplicationLifecycle.Told]) {
        for each in told {
            if let handler = tree.root?.first(type: each.element)?.handler(each.event) {
                pump.handlers.enqueuePhase(handler)
            }
        }
        pump.turn()
    }
}
