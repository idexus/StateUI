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

    /// How a row stands its children: on one line, or broken onto as many lines as its room needs.
    /// Design: docs/design/host/layout.md#a-row-that-wraps
    public enum Lines: Equatable, Sendable {
        /// One line, however long.
        case one

        /// Each line as many children as its room takes, at least one, the lines `spacing` apart.
        case wrapped(spacing: Double)

        /// What a row's members say: wrapped where it `wraps`, its lines `rowSpacing` apart.
        public init(_ values: ElementValues<HStackContract>) {
            self = values[HStackContract.wraps] == true ? .wrapped(spacing: values[HStackContract.rowSpacing] ?? 0) : .one
        }
    }

    /// The room a stack's shown children take, each measured once for the width offered - a row's words at the width
    /// it would give them in that room, so it is as tall as they stand there.
    @MainActor
    public static func size<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, lines: Lines = .one, padding: Insets, width offered: Double?
    ) -> LayoutSize {
        let visible = items.filter(\.isShown)
        if axis == .horizontal, case .wrapped(let lineSpacing) = lines, let offered {
            let room = max(0, offered - padding.start - padding.end)
            let sizes = broken(visible, spacing: spacing, room: room).map { line in
                size(of: line.map { visible[$0] }, axis: .horizontal, spacing: spacing, padding: Insets(0), width: room)
            }
            return LayoutSize(
                width: padding.start + padding.end + (sizes.map(\.width).max() ?? 0),
                height: padding.top + padding.bottom + sizes.reduce(0) { $0 + $1.height }
                    + lineSpacing * Double(max(sizes.count - 1, 0)))
        }
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
            var naturals: [LayoutSize?] = visible.map { $0.size(offered: nil) }
            for (item, natural) in zip(visible, naturals) {
                along += (natural?.width ?? 0) + item.values.margin.start + item.values.margin.end
            }
            if let offered {
                let room = max(0, offered - padding.start - padding.end)
                naturals = wrapped(visible, naturals, rowWidths(of: visible, naturals: naturals, spacing: spacing, room: room))
            }
            // The children on a first baseline take what stands above the line and what below it.
            var (above, below) = (0.0, 0.0)
            for (item, size) in zip(visible, naturals) {
                let margin = item.values.margin
                guard item.values.vertical == Self.firstBaseline, let size else {
                    across = max(across, (size?.height ?? 0) + margin.top + margin.bottom)
                    continue
                }
                let baseline = item.firstBaseline(offered: size.width) ?? size.height
                above = max(above, margin.top + baseline)
                below = max(below, size.height - baseline + margin.bottom)
            }
            across = max(across, above + below)
            return LayoutSize(
                width: padding.start + padding.end + gaps + along,
                height: padding.top + padding.bottom + across)
        }
    }

    /// Where each child stands in `bounds`, in order; nil for a hidden one. Right to left, the places
    /// are turned about the middle of `bounds`.
    @MainActor
    public static func places<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, lines: Lines = .one, padding: Insets, in bounds: Rect,
        direction: LayoutDirection
    ) -> [Rect?] {
        leftToRight(of: items, axis: axis, spacing: spacing, lines: lines, padding: padding, in: bounds)
            .map { $0.map { direction.places($0, in: bounds) } }
    }

    /// The places as a layout written left to right has them - a wrapped row's line by line, each line in its own
    /// room across the content, as tall as its children stand on it.
    /// Design: docs/design/host/layout.md#a-row-that-wraps
    @MainActor
    private static func leftToRight<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, lines: Lines, padding: Insets, in bounds: Rect
    ) -> [Rect?] {
        guard axis == .horizontal, case .wrapped(let lineSpacing) = lines else {
            return oneLine(of: items, axis: axis, spacing: spacing, padding: padding, in: bounds)
        }
        let content = bounds.inset(padding)
        var places = [Rect?](repeating: nil, count: items.count)
        var y = content.y
        for line in broken(items, spacing: spacing, room: content.width) {
            let children = line.map { items[$0] }
            let height = size(of: children, axis: .horizontal, spacing: spacing, padding: Insets(0), width: content.width)
                .height
            let room = Rect(x: content.x, y: y, width: content.width, height: height)
            for (index, place) in zip(line, oneLine(of: children, axis: .horizontal, spacing: spacing, padding: Insets(0), in: room)) {
                places[index] = place
            }
            y += height + lineSpacing
        }
        return places
    }

    /// The places on one line as a layout written left to right has them: each child measured once, a growing one
    /// given its share of the room the others leave.
    /// Design: docs/design/host/layout.md#a-space
    @MainActor
    private static func oneLine<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, padding: Insets, in bounds: Rect
    ) -> [Rect?] {
        let content = bounds.inset(padding)
        let cross = axis == .vertical ? content.width : content.height
        var naturals: [LayoutSize?] = items.map { item in
            guard item.isShown else { return nil }
            let margin = item.values.margin
            return item.size(offered: axis == .vertical ? max(0, cross - margin.start - margin.end) : nil)
        }
        // A row short of room takes it from its words, which stand at the width they are measured at.
        let row = axis == .horizontal ? rowWidths(of: items, naturals: naturals, spacing: spacing, room: content.width) : nil
        if let row { naturals = wrapped(items, naturals, row) }
        let share = row?.yielded == true
            ? 0 : growingShare(of: items, naturals: naturals, axis: axis, spacing: spacing, in: content)
        var offset = axis == .vertical ? content.y : content.x
        // In a row, each child on a first baseline at the width it is placed, and the line they rest on.
        let baselines: [Double?] = axis == .vertical ? [] : zip(items, naturals).enumerated().map { index, pair in
            guard pair.0.values.vertical == Self.firstBaseline, let natural = pair.1 else { return nil }
            let width = row?.widths[index] ?? natural.width
            return pair.0.firstBaseline(offered: width) ?? natural.height
        }
        let line = zip(items, baselines).compactMap { item, baseline in baseline.map { item.values.margin.top + $0 } }
            .max() ?? 0

        return zip(items, naturals).enumerated().map { index, pair in
            let (item, natural) = pair
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
                let y = baselines[index].map { content.y + line - $0 } ?? Extent.start(
                    option: values.vertical, extent: height, start: content.y + margin.top, available: available)
                let width = values.grows(along: axis)
                    ? values.boundedWidth(share) : row?.widths[index] ?? values.boundedWidth(natural.width)
                let place = Rect(x: offset, y: y, width: width, height: height)
                offset += width + margin.end + spacing
                return place
            }
        }
    }

    /// What a child's vertical alignment says where it rests on a row's first baseline.
    static let firstBaseline = Alignment.firstBaseline.rawValue

    /// How far below a stack's top its first line of words rests, laid out in `bounds`: its first shown child's
    /// with one - in a row, on the line its first-baseline children rest on; nil where no child has words.
    /// Design: docs/design/host/layout.md#a-first-baseline
    @MainActor
    public static func firstBaseline<Child: LayoutChild>(
        of items: [Child], axis: Axis, spacing: Double, lines: Lines = .one, padding: Insets, in bounds: Rect
    ) -> Double? {
        let places = leftToRight(of: items, axis: axis, spacing: spacing, lines: lines, padding: padding, in: bounds)
        for (item, place) in zip(items, places) {
            guard let place, let baseline = item.firstBaseline(offered: place.width) else { continue }
            return place.y - bounds.y + baseline
        }
        return nil
    }

    /// Each child's width along a row: its natural width - and, where the row has less room than its shown children,
    /// their margins and the spacing need, the words (`yieldsInARow`) sharing what the others leave in proportion to
    /// their natural widths, the others keeping theirs; nil for a hidden child, nothing for one that grows.
    /// Design: docs/design/host/layout.md#a-row-short-of-room
    @MainActor
    private static func rowWidths<Child: LayoutChild>(
        of items: [Child], naturals: [LayoutSize?], spacing: Double, room: Double
    ) -> (widths: [Double?], yielded: Bool) {
        let widths: [Double?] = zip(items, naturals).map { item, natural in
            natural.map { item.values.grows(along: .horizontal) ? 0 : item.values.boundedWidth($0.width) }
        }
        let shown = items.indices.filter { widths[$0] != nil }
        let margins = shown.reduce(0.0) { $0 + items[$1].values.margin.start + items[$1].values.margin.end }
        let needed = shown.reduce(margins) { $0 + (widths[$1] ?? 0) } + spacing * Double(max(shown.count - 1, 0))
        let words = shown.filter { items[$0].values.yieldsInARow }
        let wordsWidth = words.reduce(0.0) { $0 + (widths[$1] ?? 0) }
        guard needed > room, wordsWidth > 0 else { return (widths, false) }

        let left = max(0, room - (needed - wordsWidth))
        var yielded = widths
        for index in words {
            yielded[index] = items[index].values.boundedWidth((widths[index] ?? 0) * left / wordsWidth)
        }
        return (yielded, true)
    }

    /// The shown children's indices line by line: each line as many as `room` takes at their natural widths with
    /// their margins and the spacing between them, at least one - a growing child taking none of it.
    /// Design: docs/design/host/layout.md#a-row-that-wraps
    @MainActor
    private static func broken<Child: LayoutChild>(_ items: [Child], spacing: Double, room: Double) -> [[Int]] {
        var lines: [[Int]] = []
        var line: [Int] = []
        var taken = 0.0
        for (index, item) in items.enumerated() where item.isShown {
            let values = item.values
            let natural = values.grows(along: .horizontal) ? 0 : values.boundedWidth(item.size(offered: nil).width)
            let width = values.margin.start + natural + values.margin.end
            if !line.isEmpty, taken + spacing + width > room {
                lines.append(line)
                (line, taken) = ([], 0)
            }
            taken += (line.isEmpty ? 0 : spacing) + width
            line.append(index)
        }
        return line.isEmpty ? lines : lines + [line]
    }

    /// `naturals` with each child a row narrowed measured again at its width, so its words wrap to it.
    @MainActor
    private static func wrapped<Child: LayoutChild>(
        _ items: [Child], _ naturals: [LayoutSize?], _ row: (widths: [Double?], yielded: Bool)
    ) -> [LayoutSize?] {
        guard row.yielded else { return naturals }
        return zip(items, zip(naturals, row.widths)).map { item, pair in
            guard let natural = pair.0, let width = pair.1, item.values.yieldsInARow,
                  width < item.values.boundedWidth(natural.width) else { return pair.0 }
            return item.size(offered: width)
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

    /// Whether the child gives up width in a row short of room: words alone (a label), stating no width of their own.
    public var yieldsInARow: Bool {
        words == .bare && width == nil
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
