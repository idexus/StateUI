// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A ZStack's arithmetic: each shown child in its area - the room within the padding, or the rectangle it
/// names - standing there by its own alignments, as one child stands in its room.
/// Design: docs/design/host/layout.md#layers
@_spi(Host) public enum ZStackArithmetic {
    /// The room the children and the padding take for the width offered: as much as the child that needs the
    /// most, at its natural size.
    @MainActor
    public static func size<Child: LayoutChild>(of items: [Child], padding: Insets, width offered: Double?) -> LayoutSize {
        let inner = offered.map { max(0, $0 - padding.left - padding.right) }
        var width = 0.0
        var height = 0.0

        for item in items where item.isShown {
            let needs = room(for: item, width: inner)
            width = max(width, needs.width)
            height = max(height, needs.height)
        }

        return LayoutSize(width: padding.left + padding.right + width, height: padding.top + padding.bottom + height)
    }

    /// Where each child stands in `room`, within `padding`, in order; nil for a hidden one. Right to left,
    /// turned about the room's middle.
    @MainActor
    public static func places<Child: LayoutChild>(
        of items: [Child], in room: Rect, padding: Insets, direction: LayoutDirection = .leftToRight
    ) -> [Rect?] {
        let content = room.inset(padding)
        return items.map { item in
            guard item.isShown else { return nil }
            let area = rectangle(of: item.values.area, in: content)
            return direction.places(SingleChildArithmetic.place(of: item, in: area, padding: Insets(0)), in: room)
        }
    }

    /// The rectangle an area names in `content`; the whole of it where the child names none.
    private static func rectangle(of area: Area?, in content: Rect) -> Rect {
        switch area {
        case let .absolute(x, y, width, height)?:
            return Rect(x: content.x + x, y: content.y + y, width: max(0, width), height: max(0, height))
        case let .proportional(x, y, width, height)?:
            return Rect(
                x: content.x + x * content.width, y: content.y + y * content.height,
                width: max(0, width * content.width), height: max(0, height * content.height))
        case nil:
            return content
        }
    }

    /// The room one child needs at its natural size: where its area ends, or as much as leaves its share
    /// of the room enough for it.
    @MainActor
    private static func room<Child: LayoutChild>(for item: Child, width offered: Double?) -> LayoutSize {
        let margin = item.values.margin
        switch item.values.area {
        case let .absolute(x, y, width, height)?:
            return LayoutSize(width: max(0, x + width), height: max(0, y + height))
        case let .proportional(_, _, width, height)?:
            let natural = item.size(offered: offered.map { $0 * width })
            return LayoutSize(
                width: width > 0 ? (natural.width + margin.left + margin.right) / width : 0,
                height: height > 0 ? (natural.height + margin.top + margin.bottom) / height : 0)
        case nil:
            let natural = item.size(offered: offered)
            return LayoutSize(
                width: natural.width + margin.left + margin.right,
                height: natural.height + margin.top + margin.bottom)
        }
    }
}
