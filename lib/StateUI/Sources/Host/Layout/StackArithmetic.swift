// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A stack's arithmetic: its shown children one after another along one axis.
/// Design: docs/design/host/layout.md#stacks
@_spi(Host) public enum StackArithmetic {
    /// The axis a stack runs along.
    public enum Axis: Sendable {
        /// Left to right.
        case horizontal

        /// Top to bottom.
        case vertical
    }

    /// The room a stack's shown children take, each measured once for the width offered.
    @MainActor
    public static func size<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, padding: Insets, width offered: Double?
    ) -> LayoutSize {
        let visible = items.filter(\.isShown)
        let gaps = spacing * Double(max(visible.count - 1, 0))
        var along = 0.0
        var across = 0.0

        switch axis {
        case .vertical:
            let childWidth = offered.map { max(0, $0 - padding.left - padding.right) }
            for item in visible {
                let size = item.size(offered: childWidth)
                let margin = item.values.margin
                along += size.height + margin.top + margin.bottom
                across = max(across, size.width + margin.left + margin.right)
            }
            return LayoutSize(
                width: padding.left + padding.right + across,
                height: padding.top + padding.bottom + gaps + along)

        case .horizontal:
            for item in visible {
                let size = item.size(offered: nil)
                let margin = item.values.margin
                along += size.width + margin.left + margin.right
                across = max(across, size.height + margin.top + margin.bottom)
            }
            return LayoutSize(
                width: padding.left + padding.right + gaps + along,
                height: padding.top + padding.bottom + across)
        }
    }

    /// Where each child stands in `bounds`, in order; nil for a hidden one. Right to left, the places
    /// are turned about the middle of `bounds`.
    @MainActor
    public static func places<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, padding: Insets, in bounds: Rect,
        direction: LayoutDirection
    ) -> [Rect?] {
        leftToRight(of: items, axis: axis, spacing: spacing, padding: padding, in: bounds)
            .map { $0.map { direction.places($0, in: bounds) } }
    }

    /// The places as a layout written left to right has them.
    @MainActor
    private static func leftToRight<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, padding: Insets, in bounds: Rect
    ) -> [Rect?] {
        let content = bounds.inset(padding)
        var offset = axis == .vertical ? content.y : content.x

        return items.map { item in
            guard item.isShown else { return nil }
            let values = item.values
            let margin = values.margin
            let cross = axis == .vertical ? content.width : content.height
            let natural = item.size(offered: axis == .vertical ? cross : nil)

            switch axis {
            case .vertical:
                offset += margin.top
                let available = max(0, content.width - margin.left - margin.right)
                let width = Extent.of(
                    option: values.horizontal, stated: values.width, natural: natural.width,
                    available: available, minimum: values.minimumWidth, maximum: values.maximumWidth)
                let x = Extent.start(
                    option: values.horizontal, extent: width, start: content.x + margin.left, available: available)
                let height = values.boundedHeight(natural.height)
                let place = Rect(x: x, y: offset, width: width, height: height)
                offset += height + margin.bottom + spacing
                return place

            case .horizontal:
                offset += margin.left
                let available = max(0, content.height - margin.top - margin.bottom)
                let height = Extent.of(
                    option: values.vertical, stated: values.height, natural: natural.height,
                    available: available, minimum: values.minimumHeight, maximum: values.maximumHeight)
                let y = Extent.start(
                    option: values.vertical, extent: height, start: content.y + margin.top, available: available)
                let width = values.boundedWidth(natural.width)
                let place = Rect(x: offset, y: y, width: width, height: height)
                offset += width + margin.right + spacing
                return place
            }
        }
    }
}

extension LayoutDirection {
    /// Where a place worked out left to right stands in `room` laid out this way: right to left, turned
    /// about the room's middle, so a row fills from the right and padding and margins swap sides.
    /// Design: docs/design/host/layout.md#right-to-left
    func places(_ place: Rect, in room: Rect) -> Rect {
        guard self == .rightToLeft else { return place }
        return Rect(x: room.x + room.width - (place.x - room.x) - place.width, y: place.y,
                    width: place.width, height: place.height)
    }
}

extension Rect {
    /// This rectangle with `insets` taken off each side, never below no room.
    func inset(_ insets: Insets) -> Rect {
        Rect(
            x: x + insets.left,
            y: y + insets.top,
            width: max(0, width - insets.left - insets.right),
            height: max(0, height - insets.top - insets.bottom))
    }
}
