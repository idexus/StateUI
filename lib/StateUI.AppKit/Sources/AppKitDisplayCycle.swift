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

    /// Wears one state's image on every control tied to it.
    func present(state: Int32, value: HostStateValue)

    /// Wears states' images on every control tied to them.
    func present(states: [Int32: HostStateValue])

    /// Draws the described properties that moved, per mounted element.
    func present(properties: [UInt64: Set<Prop>])

    /// Renders when the core has changed since the last render.
    func renderIfNeeded()
}

/// One frame of the display's clock, in the order every runtime keeps.
///
/// (1) The reader's reports since the last frame are committed as one
/// transaction. (2) The walker steps every trip; the state channels and the
/// described motion follow it, and the channels' reports reach the core before
/// its cycle. (3) The core's cycle runs, and the state channels wear its
/// changes. (4) What moved is presented. (5) A render follows when the core
/// needs one. (6) The frame clock stays held while anything still moves, and
/// lets go only here, after a whole frame.
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

    /// Steps the trips, runs the core's cycle and presents what moved, then
    /// holds the clock while anything still does.
    func drain(now: Double) {
        let reducesMotion = reducesMotion()
        stepTrips(now: now, reducesMotion: reducesMotion)

        let cycle = core.cycle(now: now, reducesMotion: reducesMotion)

        for change in cycle.changes {
            stateChannels.receive(change, now: now, reducesMotion: reducesMotion)
            presenter?.present(state: change.state, value: change.value)
        }

        presentStateChannels()

        continues = cycle.continues
        hold()
    }

    /// Steps every trip to `now` and presents what the steps moved.
    func stepTrips(now: Double, reducesMotion: Bool) {
        let steps = walker.step(now: now, reducesMotion: reducesMotion)
        stateChannels.follow(steps)
        describedMotion.follow(steps)
        presentStateChannels()
        presentDescribedMotion()
    }

    /// Hands the state channels' journeys on: their reports to the core, their
    /// values to every control tied to them, and each finished journey's
    /// answer to whoever awaited it.
    func presentStateChannels() {
        var valuesByState: [Int32: HostStateValue] = [:]

        for output in stateChannels.takeOutputs() {
            valuesByState[output.state] = StateUIHost.value(of: output.journey)

            if let report = output.report {
                _ = core.report(output.journey, updating: report, through: output.binding)
            }
        }

        if !valuesByState.isEmpty {
            presenter?.present(states: valuesByState)
        }

        for completion in stateChannels.takeCompletions() {
            _ = core.complete(completion.id, succeeded: completion.succeeded)
        }
    }

    /// Draws the described properties the last step moved.
    func presentDescribedMotion() {
        var propertiesByMount: [UInt64: Set<Prop>] = [:]
        for output in describedMotion.takeOutputs() {
            propertiesByMount[output.key.mount, default: []].insert(output.key.property)
        }

        if !propertiesByMount.isEmpty {
            presenter?.present(properties: propertiesByMount)
        }
    }

    /// Holds the frame clock while anything still moves or owes a frame: a
    /// trip, the core's cycle, a scroller moving or with a report to make.
    func hold() {
        clock.held = continues
            || walker.isMoving
            || core.cyclesPending
            || presenter?.wantsFrames == true
    }
}
#endif
