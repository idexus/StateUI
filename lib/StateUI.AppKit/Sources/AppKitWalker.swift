// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
@_spi(Host) import StateUI

/// What a trip moves: a state's channel, or a property a patch described.
enum AppKitTripTarget: Hashable, Comparable {
    /// The channel of the state with this number.
    case state(Int32)

    /// A property a patch described, on one mounted element.
    case described(AppKitDescribedKey)

    /// States first, by number; then described properties, by element and
    /// property.
    static func < (left: Self, right: Self) -> Bool {
        switch (left, right) {
        case (.state(let a), .state(let b)): return a < b
        case (.described(let a), .described(let b)): return a < b
        case (.state, .described): return true
        case (.described, .state): return false
        }
    }
}

/// One walked value: where it began, where it is going, how fast it was going
/// then, under which law and since when.
///
/// Pure: where it stands is `HostMotionLaw` at the time handed in, so a
/// hand-wound clock reproduces every frame.
struct AppKitTrip: Equatable {
    /// Where each lane began.
    let from: [Double]

    /// Where each lane is going.
    let destination: [Double]

    /// How fast each lane was going when it began, per millisecond.
    let velocity: [Double]

    /// The law it walks under.
    let motion: Motion

    /// When it began, in the frame clock's milliseconds.
    let began: Double

    /// Where the trip stands at `now`: each lane's value and velocity, per
    /// millisecond, and whether it has arrived.
    func position(at now: Double) -> (value: [Double], velocity: [Double], rested: Bool) {
        let sample = HostMotionLaw.sample(
            motion,
            elapsed: max(0, now - began),
            from: from,
            destination: destination,
            velocity: velocity)
        return (sample.value, sample.velocity, sample.rested)
    }

    /// Whether it begins where it ends, standing still: an arrival with
    /// nothing to walk.
    var arrives: Bool {
        zip(from, destination).allSatisfy { abs($0 - $1) < HostMotionLaw.still }
            && velocity.allSatisfy { abs($0) < HostMotionLaw.still }
    }
}

/// Where one trip stands after a step of the walker.
struct AppKitStep {
    /// What the trip moves.
    let target: AppKitTripTarget

    /// The value of each lane.
    let value: [Double]

    /// How fast each lane is going, per millisecond.
    let velocity: [Double]

    /// Whether the trip has arrived; an arrived trip has left the walker.
    let rested: Bool
}

/// The runtime's one walker: every trip, stepped together in target order.
///
/// The state channels and a patch's described motion start, replace and halt
/// their trips here and follow what each step makes of them; nothing else in
/// the host walks a value.
@MainActor
final class AppKitWalker {
    private var trips: [AppKitTripTarget: AppKitTrip] = [:]

    /// Whether any trip is under way.
    var isMoving: Bool { !trips.isEmpty }

    /// The trip under way for `target`.
    func trip(for target: AppKitTripTarget) -> AppKitTrip? {
        trips[target]
    }

    /// Starts `trip` for `target`, in place of any trip it had.
    func start(_ trip: AppKitTrip, for target: AppKitTripTarget) {
        trips[target] = trip
    }

    /// Ends `target`'s trip where it stands.
    func halt(_ target: AppKitTripTarget) {
        trips[target] = nil
    }

    /// Steps every trip to `now`, in target order.
    ///
    /// A trip that arrives leaves the walker. When the reader asks for less
    /// movement, every trip arrives at once, at its destination.
    func step(now: Double, reducesMotion: Bool = false) -> [AppKitStep] {
        var steps: [AppKitStep] = []

        for target in trips.keys.sorted() {
            guard let trip = trips[target] else { continue }

            let position = reducesMotion
                ? (trip.destination, Array(repeating: 0, count: trip.destination.count), true)
                : trip.position(at: now)

            if position.2 { trips[target] = nil }
            steps.append(AppKitStep(
                target: target, value: position.0, velocity: position.1, rested: position.2))
        }

        return steps
    }

    /// Keeps only the trips whose target `keep` still has.
    func retain(where keep: (AppKitTripTarget) -> Bool) {
        trips = trips.filter { keep($0.key) }
    }
}
#endif
