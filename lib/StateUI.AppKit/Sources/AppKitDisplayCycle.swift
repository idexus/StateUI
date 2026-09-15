// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUI

/// What a frame presents through: the mounted tree and the windows around it.
@MainActor
protocol AppKitFramePresenter: AnyObject {
    /// Whether a scroller still moves or owes a report, and so wants frames.
    var wantsFrames: Bool { get }

    /// Commits what the reader did on the scrollers since the last frame, as
    /// one transaction.
    func commitReaderReports(now: Double)

    /// Presents one frame's batch in one walk of the mounted tree: the states'
    /// images on every control tied to them, and the described properties
    /// that moved, each element's together and each ancestor arranged once.
    func present(states: [Int32: HostStateValue], properties: [UInt64: Set<Prop>])

    /// Renders when the core has changed since the last render.
    func renderIfNeeded()
}

/// One frame of the display's clock, in the order every runtime keeps.
///
/// (1) The reader's reports since the last frame are committed as one
/// transaction. (2) The walker steps every trip; the state channels and the
/// described motion follow it, and the channels' reports reach the core before
/// its cycle. (3) The core's cycle runs, and the state channels wear its
/// changes. (4) Everything the frame moved is presented in one walk, and then
/// each finished journey is answered. (5) A render follows when the core needs
/// one. (6) The frame clock stays held while anything still moves, and lets go
/// only here, after a whole frame.
///
/// A reader's own change drains the cycle inline - steps (2) to (4) and (6) -
/// so followers and engines move on the reader's frame.
@MainActor
final class AppKitDisplayCycle {
    /// What the frame presents through.
    weak var presenter: AppKitFramePresenter?

    private let core: AppKitCoreLink
    private let clock: AppKitFrameClock
    private let walker: AppKitWalker
    private let stateChannels: AppKitStateChannels
    private let describedMotion: AppKitDescribedMotion
    private let reducesMotion: () -> Bool

    /// Whether the core's last cycle said it has more to do.
    private var continues = false

    /// The frame's batch: the states' images to wear, and the described
    /// properties that moved, per mounted element.
    private var states: [Int32: HostStateValue] = [:]
    private var properties: [UInt64: Set<Prop>] = [:]

    /// A cycle over the runtime's elements, on `clock`.
    init(
        core: AppKitCoreLink,
        clock: AppKitFrameClock,
        walker: AppKitWalker,
        stateChannels: AppKitStateChannels,
        describedMotion: AppKitDescribedMotion,
        reducesMotion: @escaping () -> Bool
    ) {
        self.core = core
        self.clock = clock
        self.walker = walker
        self.stateChannels = stateChannels
        self.describedMotion = describedMotion
        self.reducesMotion = reducesMotion
    }

    /// One frame of the display's clock, (1) to (6).
    func frame(now: Double) {
        presenter?.commitReaderReports(now: now)
        drain(now: now)
        presenter?.renderIfNeeded()
    }

    /// Steps the trips, runs the core's cycle and presents what moved in one
    /// walk, then holds the clock while anything still does.
    ///
    /// - Parameters:
    ///   - now: The frame clock's time.
    ///   - reported: States a reader changed, worn by every other control tied
    ///     to them in the same walk.
    func drain(now: Double, reported: [Int32: HostStateValue] = [:]) {
        states.merge(reported) { _, reported in reported }

        let reducesMotion = reducesMotion()
        follow(walker.step(now: now, reducesMotion: reducesMotion))

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

    /// Steps every trip to `now` and presents what the steps moved.
    func stepTrips(now: Double, reducesMotion: Bool) {
        follow(walker.step(now: now, reducesMotion: reducesMotion))
        present()
    }

    /// Presents the state channels' journeys on their own - after a render
    /// has attached new channels.
    func presentStateChannels() {
        collectStateChannels()
        present()
    }

    /// Holds the frame clock while anything still moves or owes a frame: a
    /// trip, the core's cycle, a scroller moving or with a report to make.
    func hold() {
        clock.held = continues
            || walker.isMoving
            || core.cyclesPending
            || presenter?.wantsFrames == true
    }

    /// Lets the state channels and the described motion follow a step, and
    /// adds what they made of it to the frame's batch.
    private func follow(_ steps: [AppKitStep]) {
        stateChannels.follow(steps)
        describedMotion.follow(steps)
        collectStateChannels()

        for output in describedMotion.takeOutputs() {
            properties[output.key.mount, default: []].insert(output.key.property)
        }
    }

    /// Takes the state channels' journeys into the batch, their reports to
    /// the core at once.
    private func collectStateChannels() {
        for output in stateChannels.takeOutputs() {
            states[output.state] = StateUIHost.value(of: output.journey)

            if let report = output.report {
                _ = core.report(output.journey, updating: report, through: output.binding)
            }
        }
    }

    /// Presents the batch in one walk, then answers every journey that
    /// finished.
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
#endif
