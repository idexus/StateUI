// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The hand over a layout engine, read alike on every host: a press dragged or a trackpad's fingers reported as they
/// move, a wheel's notches with no lift - ended after a pause on the frame clock - and the speed at the lift where
/// the platform tells none. What it answers is the element's `handMoved`.
/// Design: docs/design/host/runtime.md#the-hand-over-a-layout
@_spi(Host) public struct HandReading: Sendable {
    /// One report of the hand: its phase, how far it moved what is under it since the last, and its speed as it
    /// lifts, per second.
    public struct Report: Equatable, Sendable {
        /// Where the gesture is: begun, moving, lifted or taken away.
        public let phase: GesturePhase

        /// How far the hand moved what is under it since the last report.
        public let moved: Point

        /// How fast the hand went as it lifted, per second; nought before.
        public let speed: Point

        /// A report of `phase`.
        public init(_ phase: GesturePhase, moved: Point = .zero, speed: Point = .zero) {
            self.phase = phase
            self.moved = moved
            self.speed = speed
        }
    }

    /// How long a wheel stands still before it counts as let go, in milliseconds.
    public static let pause = 150.0

    /// How far back the speed at a lift is read, in milliseconds.
    public static let reading = 100.0

    /// The shortest time a speed is read over, in milliseconds: a display frame.
    public static let frame = 16.0

    /// Whether a gesture is under way, and whether it is a wheel's.
    private var open = false
    public private(set) var isWheeling = false

    /// Whose the gesture the platform tells is: nil until its first move says. Kept after its lift, so what the
    /// platform tells after it - a trackpad's momentum - goes where the gesture went.
    public private(set) var claimed: Bool?

    /// The moves of the last `reading` milliseconds, with when each was made.
    private var moves: [(time: Double, moved: Point)] = []

    /// When the hand last moved.
    private var last = 0.0

    /// A hand not begun.
    public init() {}

    /// Whether a layout moved along `axis` claims the hand whose first move is `moved`: one more along the axis
    /// than across it. A hand not yet moving is claimed by nobody.
    public static func claims(_ moved: Point, along axis: LayoutInput.Axis) -> Bool {
        let along = abs(axis == .horizontal ? moved.x : moved.y)
        let across = abs(axis == .horizontal ? moved.y : moved.x)
        return along > 0 && along >= across
    }

    /// The hand at `phase` - a press dragged or a trackpad's fingers - moving what is under it by `moved` at `time`,
    /// lifting at `speed` where the platform tells one: a layout moved along `axis` takes a gesture whose first
    /// move is along it, and leaves the rest to whatever holds it. Whether it took this step, and what it says.
    public mutating func hand(
        _ phase: GesturePhase, moved: Point, speed: Point?, at time: Double, along axis: LayoutInput.Axis?
    ) -> (taken: Bool, reports: [Report]) {
        switch phase {
        case .began:
            claimed = nil
            return (true, [])

        case .changed:
            if claimed == nil {
                guard let axis, moved != .zero else { return (true, []) }

                claimed = Self.claims(moved, along: axis)
                guard claimed == true else { return (false, []) }

                return (true, began(at: time) + self.moved(moved, at: time))
            }
            guard claimed == true else { return (false, []) }

            return (true, self.moved(moved, at: time))

        case .ended, .cancelled:
            guard claimed == true else { return (false, []) }

            return (true, phase == .ended ? lifted(at: time, speed: speed) : cancelled())
        }
    }

    /// A wheel's notch moving what is under the hand by `moved` at `time`, over a layout moved along `axis`: taken
    /// where it moves along the axis. Whether it was, and what it says.
    public mutating func wheel(_ moved: Point, at time: Double, along axis: LayoutInput.Axis?) -> (taken: Bool, reports: [Report]) {
        guard let axis, Self.claims(moved, along: axis) else { return (false, []) }

        return (true, notched(moved, at: time))
    }

    /// The hand begins, at `time`: a wheel still open is let go first.
    public mutating func began(at time: Double) -> [Report] {
        let ended = isWheeling ? lifted(at: time, speed: .zero) : []

        open = true
        moves = []
        last = time
        return ended + [Report(.began)]
    }

    /// The hand moved what is under it by `moved`, at `time`.
    public mutating func moved(_ moved: Point, at time: Double) -> [Report] {
        guard open else { return began(at: time) + self.moved(moved, at: time) }

        moves = moves.filter { time - $0.time <= Self.reading } + [(time, moved)]
        last = time
        return [Report(.changed, moved: moved)]
    }

    /// The hand lifted at `time`, as fast as the platform says, or as its last moves say where it says nothing.
    public mutating func lifted(at time: Double, speed: Point?) -> [Report] {
        guard open else { return [] }

        let recent = moves.filter { time - $0.time <= Self.reading }
        let span = max(time - (recent.first?.time ?? time), Self.frame)
        let went = recent.reduce(Point.zero) { Point($0.x + $1.moved.x, $0.y + $1.moved.y) }
        let read = recent.isEmpty ? Point.zero : Point(went.x / span * 1_000, went.y / span * 1_000)

        open = false
        isWheeling = false
        moves = []
        return [Report(.ended, speed: speed ?? read)]
    }

    /// The platform took the hand away.
    public mutating func cancelled() -> [Report] {
        guard open else { return [] }

        open = false
        isWheeling = false
        moves = []
        return [Report(.cancelled)]
    }

    /// A wheel's notch moved what is under the hand by `moved`, at `time`: the first opens a gesture.
    public mutating func notched(_ moved: Point, at time: Double) -> [Report] {
        let begun = isWheeling ? [] : began(at: time)

        isWheeling = true
        return begun + self.moved(moved, at: time)
    }

    /// A frame at `time`: a wheel standing still for `pause` is let go, with no throw.
    public mutating func paced(at time: Double) -> [Report] {
        guard isWheeling, time - last >= Self.pause else { return [] }

        return lifted(at: time, speed: .zero)
    }
}
