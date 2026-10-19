// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The fingers on a layout, read as one hand at their middle: each finger's step moves the middle by that step over
/// how many fingers are down, and a finger landing or lifting moves it nowhere - so two fingers spreading and
/// turning about their middle hold the hand still, and moving together carry it.
/// Design: docs/design/host/runtime.md#two-fingers-over-a-layout
@_spi(Host) public struct PointerMiddle: Sendable {
    /// Where each finger down stands, by its number.
    private var fingers: [Int: Point] = [:]

    /// No finger down.
    public init() {}

    /// How many fingers are down.
    public var count: Int { fingers.count }

    /// A finger went down at `point`: the middle moves nowhere.
    public mutating func down(_ finger: Int, at point: Point) {
        fingers[finger] = point
    }

    /// A finger moved to `point`: the middle's step - its step over how many are down; none for a finger not down.
    public mutating func moved(_ finger: Int, to point: Point) -> Point {
        guard let last = fingers[finger] else { return .zero }

        fingers[finger] = point
        let count = Double(fingers.count)
        return Point((point.x - last.x) / count, (point.y - last.y) / count)
    }

    /// A finger lifted: the middle moves nowhere.
    public mutating func up(_ finger: Int) {
        fingers[finger] = nil
    }
}
