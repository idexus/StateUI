// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a value the host animates lies on the image - one state channel on the
/// host however many controls wear it. Internal: an author reaches `Journey`.
/// Design: docs/design/core/journeys.md#the-journey-lanes
struct JourneyLanes<Value: Walked>: StateValue {
    /// Where the value is; the host writes it every frame it moves.
    var value: Value

    /// Where it is going - the state's own value.
    var destination: Value

    /// How fast it is going, per second, lane by lane.
    var velocity: Value

    /// The law an animation runs under (`StateLaw`).
    var motion: Motion

    /// The negative id a waiter is registered under, or nought for nobody.
    var completion: Double = 0

    /// How many times an animation on this value stopped - a counter, so two stops
    /// are two changes.
    var stopped: Double = 0

    /// A value standing still where it says, under the element's law unless said.
    init(_ value: Value, motion: Motion = .inherited) {
        self.value = value
        self.destination = value
        self.velocity = JourneyLanes.still
        self.motion = motion
    }

    /// A value of this type at nought - a speed before anything moved.
    static var still: Value {
        Value(carried: .lanes(Array(repeating: 0, count: max(Value.lanes, 0)))) ?? value0
    }

    /// The stand-in for text, which has no numbers; nothing reads it.
    private static var value0: Value {
        Value(carried: .text(""))!
    }

    /// Every lane: value, destination, velocity, law, waiter, stops.
    var carried: StateCarried {
        .lanes(
            JourneyLanes.numbers(of: value)
                + JourneyLanes.numbers(of: destination)
                + JourneyLanes.numbers(of: velocity)
                + StateLaw.lanes(of: motion)
                + [completion, stopped])
    }

    /// And back, where the lane count is the one this type takes.
    init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == JourneyLanes.lanes else {
            return nil
        }

        let width = Value.lanes

        guard let value = Value(carried: .lanes(Array(lanes[0..<width]))),
              let destination = Value(carried: .lanes(Array(lanes[width..<(width * 2)]))),
              let velocity = Value(carried: .lanes(Array(lanes[(width * 2)..<(width * 3)])))
        else { return nil }

        self.value = value
        self.destination = destination
        self.velocity = velocity
        self.motion = StateLaw.motion(of: Array(lanes[(width * 3)..<(width * 3 + StateLaw.lanes)]))
        self.completion = lanes[width * 3 + StateLaw.lanes]
        self.stopped = lanes[width * 3 + StateLaw.lanes + 1]
    }

    /// Three of the value's widths, the law's three, and the waiter and the stops.
    static var lanes: Int { Value.lanes * 3 + StateLaw.lanes + 2 }

    /// Whatever the value it carries is in - an animated colour is a colour.
    static var moving: MotionValues { Value.moving }

    /// The numbers a value lies as - an animated value's lanes.
    private static func numbers(of value: Value) -> [Double] {
        guard case .lanes(let lanes) = value.carried else {
            return Array(repeating: 0, count: Value.lanes)
        }

        return lanes
    }

    /// Which lanes one part sits in - what a write that must be seen forces dirty.
    static func mask(of part: JourneyPart) -> UInt64 {
        let width = Value.lanes
        let range: Range<Int>

        switch part {
        case .value: range = 0..<width
        case .destination: range = width..<(width * 2)
        case .velocity: range = (width * 2)..<(width * 3)
        case .motion: range = (width * 3)..<(width * 3 + StateLaw.lanes)
        case .completion: range = (width * 3 + StateLaw.lanes)..<(width * 3 + StateLaw.lanes + 1)
        case .stopped: range = (width * 3 + StateLaw.lanes + 1)..<(width * 3 + StateLaw.lanes + 2)
        }

        return range.reduce(into: UInt64(0)) { $0 |= HostStorage.bit(of: $1) }
    }
}

/// Which part of a walked value a write is about.
enum JourneyPart {
    case value
    case destination
    case velocity
    case motion
    case completion
    case stopped
}
