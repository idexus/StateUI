// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

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

extension HostPlacementRun {
    /// Where the run stands child `index` in `room`, no size below nothing: right to left, turned about the room's
    /// middle, as a stack's places are.
    /// Design: docs/design/host/layout.md#right-to-left
    public func place(of index: Int, in room: Rect) -> Rect {
        direction.places(writtenPlace(of: index), in: room)
    }

    /// The place the run wrote for child `index`, left to right, no size below nothing - for a toolkit that stands a
    /// view from the room's right edge itself where the run stands right to left.
    public func writtenPlace(of index: Int) -> Rect {
        let bounds = placements[index].bounds
        return Rect(x: bounds.x, y: bounds.y, width: max(0, bounds.width), height: max(0, bounds.height))
    }

    /// How child `index` is drawn over its place: moved, turned and sized about its center - right to left, its move
    /// along and its turn the other way, the mirror of what the run wrote.
    public func drawing(of index: Int) -> HostDrawingTransform {
        let placement = placements[index]
        let turned = direction == .rightToLeft ? -1.0 : 1
        return HostDrawingTransform(
            translationX: placement.translationX * turned,
            translationY: placement.translationY,
            rotation: placement.rotation * turned,
            scaleX: placement.scaleX,
            scaleY: placement.scaleY)
    }
}

extension HostPlacement {
    /// How opaque the run draws its child, 0 to 1.
    public var drawnOpacity: Double {
        min(max(opacity, 0), 1)
    }

    /// How opaque the shade over its child is drawn - a card's second layer - 0 to 1.
    public var drawnShade: Double {
        min(max(shade, 0), 1)
    }
}
