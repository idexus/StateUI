// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// How fast a gesture goes, read off what it moved over the last `HandReading.reading` milliseconds, over a display
/// frame at least: the speed a hand lifts at where the platform tells none, and every continuous gesture's speed as
/// it reports - a pan's, a pinch's, a rotation's - the same on every host.
/// Design: docs/design/host/runtime.md#a-gestures-speed
@_spi(Host) public struct SpeedReading: Sendable {
    /// The moves of the last `HandReading.reading` milliseconds, with when each was made.
    private var moves: [(time: Double, moved: Point)] = []

    /// A gesture that has not moved.
    public init() {}

    /// The gesture moved by `moved` at `time`, in the frame clock's milliseconds.
    public mutating func moved(_ moved: Point, at time: Double) {
        moves = moves.filter { time - $0.time <= HandReading.reading } + [(time, moved)]
    }

    /// How fast the gesture goes at `time`, a second; nought where it moved in none of the time read.
    public func speed(at time: Double) -> Point {
        let recent = moves.filter { time - $0.time <= HandReading.reading }
        guard let first = recent.first else { return .zero }

        let span = max(time - first.time, HandReading.frame)
        let went = recent.reduce(Point.zero) { Point($0.x + $1.moved.x, $0.y + $1.moved.y) }
        return Point(went.x / span * 1_000, went.y / span * 1_000)
    }
}
