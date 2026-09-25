// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a placing run stands a ZStack's children, and in what order it draws them, the same on every host.
/// Design: docs/design/host/layout.md#a-placing-run
extension ZStackArithmetic {
    /// The drawing order of `count` children, back to front, as `placements` rank them: those the run places by
    /// their z-index, the earlier first among equals, then those it places none of, in their order.
    public static func drawingOrder(of count: Int, placedBy placements: [HostPlacement]) -> [Int] {
        let placed = min(count, placements.count)
        let ranked = (0..<placed).sorted { one, other in
            placements[one].zIndex == placements[other].zIndex
                ? one < other : placements[one].zIndex < placements[other].zIndex
        }
        return ranked + Array(placed..<max(placed, count))
    }
}

extension HostPlacement {
    /// The place the run gives its child, no size below nothing.
    public var place: Rect {
        Rect(x: bounds.x, y: bounds.y, width: max(0, bounds.width), height: max(0, bounds.height))
    }

    /// How opaque the run draws its child, 0 to 1.
    public var drawnOpacity: Double {
        min(max(opacity, 0), 1)
    }
}
