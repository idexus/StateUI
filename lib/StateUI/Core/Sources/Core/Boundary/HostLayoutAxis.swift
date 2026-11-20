// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One axis of a layout's parameters as the host keeps where the layout's motion set out: its place among the
/// parameters' numbers, and where its segments begin - round a turn where the axis comes round.
/// Design: docs/design/views/motion-layout.md#where-a-motion-set-out
@_spi(Host) public struct HostLayoutAxis: Equatable, Sendable {
    /// The axis's place among the parameters' numbers.
    public var lane: Int

    /// Where its segments begin, in one turn.
    public var segments: [Double]

    /// Where a turn begins and how far one goes, for an axis that comes round; nil for one with ends.
    public var turn: (low: Double, period: Double)?

    /// The axis at `lane` whose segments begin at `segments`, coming round as `turn` says.
    public init(lane: Int, segments: [Double], turn: (low: Double, period: Double)? = nil) {
        self.lane = lane
        self.segments = segments
        self.turn = turn
    }

    /// Where the segments begin as they come round near `value`: the turn it stands in and one either side.
    public func marks(near value: Double) -> [Double] {
        guard let turn else { return segments }

        let standing = ((value - turn.low) / turn.period).rounded(.down)
        return [standing - 1, standing, standing + 1].flatMap { each in segments.map { $0 + each * turn.period } }
    }

    /// Of the marks beyond `start` up to `value`, the one nearest `value`: the last the axis passed going from one
    /// to the other; nil where it passed none.
    public func passed(from start: Double, to value: Double) -> Double? {
        let beyond = marks(near: value).filter {
            value > start ? $0 > start && $0 <= value : $0 < start && $0 >= value
        }
        return value > start ? beyond.max() : beyond.min()
    }

    /// Whether two axes are one: the same lane, the same marks and the same turn.
    public static func == (one: HostLayoutAxis, other: HostLayoutAxis) -> Bool {
        one.lane == other.lane && one.segments == other.segments && one.turn?.low == other.turn?.low
            && one.turn?.period == other.turn?.period
    }
}
