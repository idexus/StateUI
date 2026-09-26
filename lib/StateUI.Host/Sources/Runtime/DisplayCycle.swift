// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What a frame presents through: the toolkit's mounted tree and the windows around it.
@_spi(Host) @MainActor public protocol FramePresenter: AnyObject {
    /// Whether a scroller still moves or owes a report, and so wants frames.
    var wantsFrames: Bool { get }

    /// Commits what the user did on the scrollers since the last frame, as one batch.
    func commitUserReports(now: Double)

    /// Presents one frame's batch in one walk: bound states' values and moved properties.
    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>])

    /// Renders when the core has changed since the last render.
    func renderIfNeeded()
}

/// One frame of the display's clock, in the order every runtime keeps.
/// Design: docs/design/host/runtime.md#one-frame
@_spi(Host) @MainActor public final class DisplayCycle {
    /// What the frame presents through.
    public weak var presenter: (any FramePresenter)?

    private let core: CoreLink
    private let clock: any FrameClock
    private let animator: Animator
    private let stateChannels: StateChannels
    private let describedMotion: DescribedMotion
    private let layoutMotion: LayoutMotion
    private let reducesMotion: () -> Bool

    /// Whether the core's last cycle said it has more to do.
    private var continues = false

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
        reducesMotion: @escaping () -> Bool
    ) {
        self.core = core
        self.clock = clock
        self.animator = animator
        self.stateChannels = stateChannels
        self.describedMotion = describedMotion
        self.layoutMotion = layoutMotion
        self.reducesMotion = reducesMotion
    }

    /// One frame: the user's reports, the animations, the core's cycle, one walk, a render, the hold.
    public func frame(now: Double) {
        presenter?.commitUserReports(now: now)
        drain(now: now)
        presenter?.renderIfNeeded()
    }

    /// Advances the animations, runs the core's cycle, presents what moved and holds the clock.
    /// `reported` holds states the user changed, worn by every other bound control in the same walk.
    public func drain(now: Double, reported: [Int32: HostStateValue] = [:]) {
        states.merge(reported) { _, reported in reported }

        let reducesMotion = reducesMotion()
        follow(animator.advance(to: now, reducesMotion: reducesMotion))

        let cycle = core.cycle(now: now, reducesMotion: reducesMotion)

        for change in cycle.changes {
            states[change.state] = change.value
            stateChannels.receive(change, now: now, reducesMotion: reducesMotion)
        }

        collectStateChannels()
        present()

        continues = cycle.continues
        hold()
    }

    /// Advances every animation to `now` and presents what moved.
    public func advanceAnimations(now: Double, reducesMotion: Bool) {
        follow(animator.advance(to: now, reducesMotion: reducesMotion))
        present()
    }

    /// Presents the state channels on their own, after a render attached new ones.
    public func presentStateChannels() {
        collectStateChannels()
        present()
    }

    /// Holds the frame clock while an animation, the core's cycle or a scroller still moves.
    public func hold() {
        clock.held = continues
            || animator.isMoving
            || core.cyclesPending
            || presenter?.wantsFrames == true
    }

    private func follow(_ steps: [AnimationStep]) {
        stateChannels.follow(steps)
        describedMotion.follow(steps)
        layoutMotion.follow(steps)
        collectStateChannels()

        for output in describedMotion.takeOutputs() {
            properties[output.key.mount, default: []].insert(output.key.property)
        }
    }

    /// Takes the channels' values into the batch, and their reports to the core at once.
    private func collectStateChannels() {
        for output in stateChannels.takeOutputs() {
            states[output.state] = HostBoundary.value(of: output.journey)

            if let report = output.report {
                _ = core.report(output.journey, updating: report, through: output.binding)
            }
        }
    }

    /// Presents the batch in one walk, then answers every finished animation's waiter.
    private func present() {
        if !states.isEmpty || !properties.isEmpty {
            presenter?.present(states: states, properties: properties)
        }

        states.removeAll(keepingCapacity: true)
        properties.removeAll(keepingCapacity: true)

        for completion in stateChannels.takeCompletions() {
            _ = core.complete(completion.id, succeeded: completion.succeeded)
        }
    }
}
