// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a frame presents through: the runtime, for the mounted tree and the windows around it.
@MainActor protocol FramePresenter: AnyObject {
    /// Whether a scroller still moves or owes a report, or a frame read may have moved: it wants frames.
    var wantsFrames: Bool { get }

    /// Commits what the user did on the scrollers since the last frame, then where read frames stand, as one batch.
    func commitUserReports(now: Double)

    /// Presents one frame's batch in one walk: bound states' values and moved properties.
    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>])

    /// Renders when the core has changed since the last render.
    func renderIfNeeded()

    /// The element running the layout program `slot` names, by its mount, where its children stand somewhere new;
    /// nil where none runs it or nothing moved.
    func mount(ofLayout slot: UInt64) -> UInt64?

    /// Steps the children still on their way to the places a layout program gave them, and answers the elements
    /// whose children stand somewhere new, by mount.
    func stepLayoutBodies() -> [UInt64]

    /// Whether such a child is still on its way: the frames go on for it.
    var layoutBodiesMove: Bool { get }
}

/// One frame of the display's clock, in the order every runtime keeps.
/// Design: docs/design/host/runtime.md#one-frame
@_spi(Host) @MainActor public final class DisplayCycle {
    /// What the frame presents through.
    weak var presenter: (any FramePresenter)?

    /// The runtime an open wheel's let-go is said in.
    weak var runtime: HostRuntime?

    private let core: CoreLink
    private let clock: any FrameClock
    private let animator: Animator
    private let stateChannels: StateChannels
    private let describedMotion: DescribedMotion
    private let layoutMotion: LayoutMotion
    private let sidebarSlide: SidebarSlide
    private let handPace: HandPace
    private let reducesMotion: () -> Bool

    /// Whether the core's last cycle said it has more to do.
    private var continues = false

    /// The latest time the cycle ran at. The display's frames come stamped on its clock and a turn between them on
    /// the runtime's own; neither takes the cycle back.
    /// Design: docs/design/host/runtime.md#one-frame
    private var time = -Double.infinity

    /// Whether the toolkit lays out the frame the cycle last ran at, whose time stands while it does.
    private var layingOut = false

    /// The frame's batch: bound states' values, and moved properties per mounted element.
    private var states: [Int32: HostStateValue] = [:]
    private var properties: [UInt64: Set<Prop>] = [:]

    /// A cycle over the runtime's elements, on `clock`.
    public init(
        core: CoreLink,
        clock: any FrameClock,
        animator: Animator,
        stateChannels: StateChannels,
        describedMotion: DescribedMotion,
        layoutMotion: LayoutMotion,
        sidebarSlide: SidebarSlide,
        handPace: HandPace = HandPace(),
        reducesMotion: @escaping () -> Bool
    ) {
        self.core = core
        self.clock = clock
        self.animator = animator
        self.stateChannels = stateChannels
        self.describedMotion = describedMotion
        self.layoutMotion = layoutMotion
        self.sidebarSlide = sidebarSlide
        self.handPace = handPace
        self.reducesMotion = reducesMotion
    }

    /// One frame: the user's reports, the animations, the core's cycle, one walk, the hold, a render.
    public func frame(now: Double) {
        let now = onward(now)
        HostProbe.timed(.events) { presenter?.commitUserReports(now: now) }
        if let runtime { handPace.pace(now: now, in: runtime) }
        drain(now: now)
        presenter?.renderIfNeeded()
    }

    /// Advances the animations, runs the core's cycle, presents what moved and holds the clock.
    /// `reported` holds states the user changed, worn by every other bound control in the same walk.
    public func drain(now: Double, reported: [Int32: HostStateValue] = [:]) {
        let now = onward(now)
        states.merge(reported) { _, reported in reported }

        let reducesMotion = reducesMotion()
        sidebarSlide.pace(now: now)
        HostProbe.timed(.animations) {
            follow(animator.advance(to: now, reducesMotion: reducesMotion), reducedMotion: reducesMotion)
        }

        let cycle = HostProbe.timed(.cycle) { core.cycle(now: now, reducesMotion: reducesMotion) }

        for change in cycle.changes {
            states[change.state] = change.value
            stateChannels.receive(change, now: now, reducesMotion: reducesMotion)
        }
        // A layout whose program was worked out presents where its children stand now.
        // Design: docs/design/host/layout.md#a-layout-program
        for slot in cycle.stirred {
            if let mount = presenter?.mount(ofLayout: slot) { properties[mount, default: []].insert(.area) }
        }
        // And the children still on their way to their places take this frame's step.
        // Design: docs/design/host/layout.md#bodies
        for mount in presenter?.stepLayoutBodies() ?? [] { properties[mount, default: []].insert(.area) }
        tellFrameReaders()

        collectStateChannels()
        present()

        // What an engine of the application finished is answered once its last frame is shown.
        for finished in cycle.finished {
            _ = core.complete(finished.completion, as: finished.outcome)
        }

        continues = cycle.continues
        hold()
    }

    /// Advances every animation to `now` and presents what moved.
    public func advanceAnimations(now: Double, reducesMotion: Bool) {
        let now = onward(now)
        sidebarSlide.pace(now: now)
        follow(animator.advance(to: now, reducesMotion: reducesMotion), reducedMotion: reducesMotion)
        tellFrameReaders()
        present()
        hold()
    }

    /// Presents the state channels on their own, after a render attached new ones, and holds the clock for what the
    /// render set moving.
    public func presentStateChannels() {
        collectStateChannels()
        present()
        hold()
    }

    /// Runs `body` within the toolkit's layout pass of the frame the cycle last ran at: every turn it takes runs at
    /// that frame's time, so what the pass says moves no animation on.
    /// Design: docs/design/host/runtime.md#where-a-view-stands
    public func inLayoutPass(_ body: () -> Void) {
        let outer = layingOut
        layingOut = true
        defer { layingOut = outer }
        body()
    }

    /// `now`, or the cycle's latest time where `now` stands before it or a layout pass holds the frame's.
    private func onward(_ now: Double) -> Double {
        if !layingOut || time == -.infinity { time = max(time, now) }
        return time
    }

    /// Holds the frame clock while an animation or the core's cycle moves, or the presenter wants frames.
    public func hold() {
        clock.held = continues
            || animator.isMoving
            || handPace.isOpen
            || core.cyclesPending
            || presenter?.wantsFrames == true
            || presenter?.layoutBodiesMove == true
    }

    /// Has whoever reads a frame say it again where this frame draws a view elsewhere than the last did with no
    /// toolkit laying anything out: a place its layout's run moved, a transform presented.
    /// Design: docs/design/host/runtime.md#two-rectangles
    private func tellFrameReaders() {
        let moved = properties.values.contains { !$0.isDisjoint(with: Self.presentedGeometry) }
        if moved || placesTraveled { runtime?.frames.laidOut() }
        placesTraveled = false
    }

    /// What a frame presents that moves where a view is drawn.
    private static let presentedGeometry = MountedElement.transformProperties.union([.area])

    /// Whether the animator moved a child's place on this frame.
    private var placesTraveled = false

    private func follow(_ steps: [AnimationStep], reducedMotion: Bool) {
        stateChannels.follow(steps, reducedMotion: reducedMotion)
        describedMotion.follow(steps)
        layoutMotion.follow(steps)
        if steps.contains(where: { if case .placed = $0.target { true } else { false } }) { placesTraveled = true }
        sidebarSlide.follow(steps)
        collectStateChannels()

        for output in describedMotion.takeOutputs() {
            properties[output.key.mount, default: []].insert(output.key.property)
        }
    }

    /// Takes the channels' values into the batch, and their reports to the core at once.
    private func collectStateChannels() {
        for output in stateChannels.takeOutputs() {
            states[output.state] = HostBoundary.value(of: output.journey)

            // Every report of one frame names its time: the samples the core keeps are of one frame.
            if let report = output.report {
                _ = core.report(
                    output.journey, updating: report, through: output.binding, at: time, origin: output.origin)
            }
        }
    }

    /// Presents the batch in one walk, then answers every finished animation's waiter.
    private func present() {
        if !states.isEmpty || !properties.isEmpty {
            HostProbe.timed(.present) { presenter?.present(states: states, properties: properties) }
        }

        states.removeAll(keepingCapacity: true)
        properties.removeAll(keepingCapacity: true)

        for completion in stateChannels.takeCompletions() {
            _ = core.complete(completion.id, as: completion.outcome)
        }
    }
}
