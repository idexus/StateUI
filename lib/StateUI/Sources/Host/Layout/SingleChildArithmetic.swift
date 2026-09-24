// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The arithmetic of a container with one child - a page, a border, a pane: the child within its padding.
/// Design: docs/design/host/layout.md#one-child
@_spi(Host) public enum SingleChildArithmetic {
    /// The room the child and the padding take for the width offered; the padding alone without a shown child.
    @MainActor
    public static func size<Child: LayoutChild>(of item: Child?, padding: Insets, width offered: Double?) -> LayoutSize {
        guard let item, item.isShown else {
            return LayoutSize(width: padding.left + padding.right, height: padding.top + padding.bottom)
        }

        let margin = item.values.margin
        let size = item.size(offered: offered.map { max(0, $0 - padding.left - padding.right) })
        return LayoutSize(
            width: padding.left + padding.right + margin.left + margin.right + size.width,
            height: padding.top + padding.bottom + margin.top + margin.bottom + size.height)
    }

    /// Where the child stands in `room`, within `padding`; right to left, turned about the room's middle.
    @MainActor
    public static func place<Child: LayoutChild>(
        of item: Child, in room: Rect, padding: Insets, direction: LayoutDirection
    ) -> Rect {
        direction.places(leftToRight(of: item, in: room, padding: padding), in: room)
    }

    /// The place as a layout written left to right has it.
    @MainActor
    private static func leftToRight<Child: LayoutChild>(of item: Child, in room: Rect, padding: Insets) -> Rect {
        let content = room.inset(padding)
        let values = item.values
        let margin = values.margin
        let availableWidth = max(0, content.width - margin.left - margin.right)
        let availableHeight = max(0, content.height - margin.top - margin.bottom)
        let natural = placesByNaturalSize(values) ? item.size(offered: availableWidth) : .zero
        let width = Extent.of(
            option: values.horizontal, stated: values.width, natural: natural.width,
            available: availableWidth, minimum: values.minimumWidth, maximum: values.maximumWidth)
        let height = Extent.of(
            option: values.vertical, stated: values.height, natural: natural.height,
            available: availableHeight, minimum: values.minimumHeight, maximum: values.maximumHeight)

        return Rect(
            x: Extent.start(option: values.horizontal, extent: width, start: content.x + margin.left, available: availableWidth),
            y: Extent.start(option: values.vertical, extent: height, start: content.y + margin.top, available: availableHeight),
            width: width,
            height: height)
    }

    /// Whether the child's natural size places it: on an axis it does not fill and states no size for.
    private static func placesByNaturalSize(_ values: LayoutValues) -> Bool {
        (values.horizontal != 3 && values.width == nil) || (values.vertical != 3 && values.height == nil)
    }
}
