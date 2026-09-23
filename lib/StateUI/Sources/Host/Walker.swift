// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an animation moves: a state's channel, a described property, or a layout's place.
@_spi(Host) public enum TripTarget: Hashable, Comparable {
    /// The channel of the state with this number.
    case state(Int32)

    /// A property a patch described, on one mounted element.
    case described(DescribedKey)

    /// The place a layout gave the mounted element with this key.
    case placed(UInt64)

    /// States first, then described properties, then places; each in key order.
    public static func < (left: Self, right: Self) -> Bool {
        switch (left, right) {
        case (.state(let a), .state(let b)): return a < b
        case (.described(let a), .described(let b)): return a < b
        case (.placed(let a), .placed(let b)): return a < b
        default: return left.rank < right.rank
        }
    }

    private var rank: Int {
        switch self {
        case .state: return 0
        case .described: return 1
        case .placed: return 2
        }
    }
}

/// One running animation of a value, pure in the time handed to it.
/// Design: docs/design/host/motion.md#one-walker
@_spi(Host) public struct Trip: Equatable {
    /// Where each lane began.
    public let from: [Double]

    /// Where each lane is going.
    public let destination: [Double]

    /// Each lane's speed when it began, per millisecond.
    public let velocity: [Double]

    /// The timing it runs under.
    public let motion: Motion

    /// When it began, in the frame clock's milliseconds.
    public let began: Double

    /// A trip from `from` to `destination`, begun at `began`.
    public init(from: [Double], destination: [Double], velocity: [Double], motion: Motion, began: Double) {
        self.from = from
        self.destination = destination
        self.velocity = velocity
        self.motion = motion
        self.began = began
    }

    /// Each lane's value and speed at `now`, and whether it has arrived.
    public func position(at now: Double) -> (value: [Double], velocity: [Double], rested: Bool) {
        let sample = HostMotionLaw.sample(
            motion, elapsed: max(0, now - began), from: from, destination: destination, velocity: velocity)
        return (sample.value, sample.velocity, sample.rested)
    }

    /// Whether it starts where it ends, standing still: nothing to animate.
    public var arrives: Bool {
        zip(from, destination).allSatisfy { abs($0 - $1) < HostMotionLaw.still }
            && velocity.allSatisfy { abs($0) < HostMotionLaw.still }
    }
}

/// Where one trip stands after a step of the walker.
@_spi(Host) public struct Step {
    /// What the trip moves.
    public let target: TripTarget

    /// Each lane's value.
    public let value: [Double]

    /// Each lane's speed, per millisecond.
    public let velocity: [Double]

    /// Whether the trip arrived; an arrived trip has left the walker.
    public let rested: Bool
}

/// The runtime's one animator: every trip, stepped together in target order.
/// Design: docs/design/host/motion.md#one-walker
@_spi(Host) @MainActor public final class Walker {
    private var trips: [TripTarget: Trip] = [:]

    /// A walker with no trip under way.
    public init() {}

    /// Whether any trip is under way.
    public var isMoving: Bool { !trips.isEmpty }

    /// The trip under way for `target`.
    public func trip(for target: TripTarget) -> Trip? { trips[target] }

    /// Starts `trip` for `target`, in place of any trip it had.
    public func start(_ trip: Trip, for target: TripTarget) { trips[target] = trip }

    /// Ends `target`'s trip where it stands.
    public func halt(_ target: TripTarget) { trips[target] = nil }

    /// Steps every trip to `now` in target order; with less motion, each one arrives.
    public func step(now: Double, reducesMotion: Bool = false) -> [Step] {
        var steps: [Step] = []

        for target in trips.keys.sorted() {
            guard let trip = trips[target] else { continue }

            let position = reducesMotion
                ? (trip.destination, Array(repeating: 0, count: trip.destination.count), true)
                : trip.position(at: now)

            if position.2 { trips[target] = nil }
            steps.append(Step(target: target, value: position.0, velocity: position.1, rested: position.2))
        }

        return steps
    }

    /// Keeps only the trips whose target `keep` still has.
    public func retain(where keep: (TripTarget) -> Bool) {
        trips = trips.filter { keep($0.key) }
    }
}
