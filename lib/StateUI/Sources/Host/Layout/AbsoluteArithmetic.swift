// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An absolute layout's arithmetic: each shown child at its own bounds, in points or in fractions of the layout.
/// Design: docs/design/host/layout.md#absolute-bounds
@_spi(Host) public enum AbsoluteArithmetic {
    /// The room the children's bounds reach, at their natural sizes whatever width is offered.
    @MainActor
    public static func size<Child: LayoutChild>(of items: [Child]) -> LayoutSize {
        var width = 0.0
        var height = 0.0

        for item in items where item.isShown {
            let natural = item.size(offered: nil)
            let bounds = item.values.absoluteBounds ?? [0, 0, -1, -1]
            let childWidth = bounds.count > 2 && bounds[2] >= 0 ? bounds[2] : natural.width
            let childHeight = bounds.count > 3 && bounds[3] >= 0 ? bounds[3] : natural.height
            width = max(width, (bounds.first ?? 0) + childWidth)
            height = max(height, (bounds.count > 1 ? bounds[1] : 0) + childHeight)
        }

        return LayoutSize(width: width, height: height)
    }

    /// Where each child stands in a layout of `room`, in order; nil for a hidden one. Right to left, x
    /// counts from the right edge.
    @MainActor
    public static func places<Child: LayoutChild>(
        of items: [Child], in room: LayoutSize, direction: LayoutDirection = .leftToRight
    ) -> [Rect?] {
        let bounds = Rect(x: 0, y: 0, width: room.width, height: room.height)
        return leftToRight(of: items, in: room).map { $0.map { direction.places($0, in: bounds) } }
    }

    /// The places as a layout written left to right has them.
    @MainActor
    private static func leftToRight<Child: LayoutChild>(of items: [Child], in room: LayoutSize) -> [Rect?] {
        items.map { item in
            guard item.isShown else { return nil }
            let values = item.values
            let bounds = values.absoluteBounds ?? [0, 0, -1, -1]
            let natural = item.size(offered: nil)
            let flags = values.absoluteProportions
            var width = bounds.count > 2 ? bounds[2] : natural.width
            var height = bounds.count > 3 ? bounds[3] : natural.height

            if width < 0 { width = natural.width }
            if height < 0 { height = natural.height }
            if flags & 4 != 0 { width *= room.width }
            if flags & 8 != 0 { height *= room.height }
            width = values.boundedWidth(width)
            height = values.boundedHeight(height)

            var x = bounds.first ?? 0
            var y = bounds.count > 1 ? bounds[1] : 0
            if flags & 1 != 0 { x *= max(0, room.width - width) }
            if flags & 2 != 0 { y *= max(0, room.height - height) }

            return Rect(x: x, y: y, width: width, height: height)
        }
    }
}
