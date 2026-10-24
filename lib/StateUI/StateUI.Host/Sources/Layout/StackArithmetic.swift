// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

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
            let childWidth = offered.map { max(0, $0 - padding.start - padding.end) }
            for item in visible {
                let margin = item.values.margin
                let size = item.size(offered: childWidth.map { max(0, $0 - margin.start - margin.end) })
                along += size.height + margin.top + margin.bottom
                across = max(across, size.width + margin.start + margin.end)
            }
            return LayoutSize(
                width: padding.start + padding.end + across,
                height: padding.top + padding.bottom + gaps + along)

        case .horizontal:
            for item in visible {
                let size = item.size(offered: nil)
                let margin = item.values.margin
                along += size.width + margin.start + margin.end
                across = max(across, size.height + margin.top + margin.bottom)
            }
            return LayoutSize(
                width: padding.start + padding.end + gaps + along,
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

    /// The places as a layout written left to right has them: each child measured once, a growing one given its
    /// share of the room the others leave.
    /// Design: docs/design/host/layout.md#a-space
    @MainActor
    private static func leftToRight<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, padding: Insets, in bounds: Rect
    ) -> [Rect?] {
        let content = bounds.inset(padding)
        let cross = axis == .vertical ? content.width : content.height
        let naturals: [LayoutSize?] = items.map { item in
            guard item.isShown else { return nil }
            let margin = item.values.margin
            return item.size(offered: axis == .vertical ? max(0, cross - margin.start - margin.end) : nil)
        }
        let share = growingShare(of: items, naturals: naturals, axis: axis, spacing: spacing, in: content)
        var offset = axis == .vertical ? content.y : content.x

        return zip(items, naturals).map { item, natural in
            guard let natural else { return nil }
            let values = item.values
            let margin = values.margin

            switch axis {
            case .vertical:
                offset += margin.top
                let available = max(0, content.width - margin.start - margin.end)
                let width = Extent.of(
                    option: values.horizontal, stated: values.width, natural: natural.width,
                    available: available, minimum: values.minimumWidth, maximum: values.maximumWidth)
                let x = Extent.start(
                    option: values.horizontal, extent: width, start: content.x + margin.start, available: available)
                let height = values.boundedHeight(values.grows(along: axis) ? share : natural.height)
                let place = Rect(x: x, y: offset, width: width, height: height)
                offset += height + margin.bottom + spacing
                return place

            case .horizontal:
                offset += margin.start
                let available = max(0, content.height - margin.top - margin.bottom)
                let height = Extent.of(
                    option: values.vertical, stated: values.height, natural: natural.height,
                    available: available, minimum: values.minimumHeight, maximum: values.maximumHeight)
                let y = Extent.start(
                    option: values.vertical, extent: height, start: content.y + margin.top, available: available)
                let width = values.boundedWidth(values.grows(along: axis) ? share : natural.width)
                let place = Rect(x: offset, y: y, width: width, height: height)
                offset += width + margin.end + spacing
                return place
            }
        }
    }

    /// What each growing child takes along the stack: the room the shown children leave, with their margins and the
    /// spacing, split alike; none where nothing is left.
    @MainActor
    private static func growingShare<Child: LayoutChild>(
        of items: [Child], naturals: [LayoutSize?], axis: Axis, spacing: Double, in content: Rect
    ) -> Double {
        let shown = zip(items, naturals).compactMap { item, natural in natural.map { (item, $0) } }
        let growing = shown.filter { $0.0.values.grows(along: axis) }.count
        guard growing > 0 else { return 0 }

        let taken = shown.reduce(0.0) { sum, pair in
            let (item, natural) = pair
            let margin = item.values.margin
            switch axis {
            case .vertical:
                return sum + margin.top + margin.bottom + (item.values.grows(along: axis) ? 0 : item.values.boundedHeight(natural.height))
            case .horizontal:
                return sum + margin.start + margin.end + (item.values.grows(along: axis) ? 0 : item.values.boundedWidth(natural.width))
            }
        }
        let length = axis == .vertical ? content.height : content.width
        return max(0, length - taken - spacing * Double(shown.count - 1)) / Double(growing)
    }
}

extension LayoutValues {
    /// Whether the child takes a share of the room along `axis`: it grows and states no length of its own there.
    public func grows(along axis: StackArithmetic.Axis) -> Bool {
        grows && (axis == .vertical ? height : width) == nil
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
            x: x + insets.start,
            y: y + insets.top,
            width: max(0, width - insets.start - insets.end),
            height: max(0, height - insets.top - insets.bottom))
    }
}
