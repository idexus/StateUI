// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A grid's arithmetic: fixed, automatic and proportional tracks, and each shown child in its cells.
/// Design: docs/design/host/layout.md#grids
@_spi(Host) public enum GridArithmetic {
    /// The room the grid takes at its tracks' natural sizes. Where that is wider than the width offered, the
    /// columns share the offer as a placement would, and each row is as tall as its children at those widths.
    @MainActor
    public static func size<Child: LayoutChild>(
        of items: [Child], rows: [GridLength], columns: [GridLength],
        rowSpacing: Double, columnSpacing: Double, padding: Insets, width offered: Double? = nil
    ) -> LayoutSize {
        let (rowCount, columnCount) = counts(items, rows: rows, columns: columns)
        let columnDefinitions = completed(columns, count: columnCount)
        var columnSizes = trackSizes(
            items, definitions: columnDefinitions, count: columnCount,
            available: nil, spacing: columnSpacing, vertical: false)
        let width = padding.left + padding.right + columnSizes.reduce(0, +)
            + columnSpacing * Double(max(columnCount - 1, 0))

        if let offered, width > offered {
            columnSizes = trackSizes(
                items, definitions: columnDefinitions, count: columnCount,
                available: max(0, offered - padding.left - padding.right), spacing: columnSpacing, vertical: false)
        }
        let rowSizes = trackSizes(
            items, definitions: completed(rows, count: rowCount), count: rowCount,
            available: nil, spacing: rowSpacing, vertical: true, columns: (columnSizes, columnSpacing))

        return LayoutSize(
            width: width,
            height: padding.top + padding.bottom + rowSizes.reduce(0, +)
                + rowSpacing * Double(max(rowCount - 1, 0)))
    }

    /// Where each child stands in `bounds`, in order; nil for a hidden one. Right to left, column 0 is
    /// the rightmost.
    @MainActor
    public static func places<Child: LayoutChild>(
        of items: [Child], rows: [GridLength], columns: [GridLength],
        rowSpacing: Double, columnSpacing: Double, padding: Insets, in bounds: Rect,
        direction: LayoutDirection
    ) -> [Rect?] {
        leftToRight(
            of: items, rows: rows, columns: columns, rowSpacing: rowSpacing,
            columnSpacing: columnSpacing, padding: padding, in: bounds)
            .map { $0.map { direction.places($0, in: bounds) } }
    }

    /// The places as a grid written left to right has them.
    @MainActor
    private static func leftToRight<Child: LayoutChild>(
        of items: [Child], rows: [GridLength], columns: [GridLength],
        rowSpacing: Double, columnSpacing: Double, padding: Insets, in bounds: Rect
    ) -> [Rect?] {
        let content = bounds.inset(padding)
        let (rowCount, columnCount) = counts(items, rows: rows, columns: columns)
        let columnSizes = trackSizes(
            items, definitions: completed(columns, count: columnCount), count: columnCount,
            available: content.width, spacing: columnSpacing, vertical: false)
        let rowSizes = trackSizes(
            items, definitions: completed(rows, count: rowCount), count: rowCount,
            available: content.height, spacing: rowSpacing, vertical: true, columns: (columnSizes, columnSpacing))
        let rowOrigins = origins(of: rowSizes, start: content.y, spacing: rowSpacing)
        let columnOrigins = origins(of: columnSizes, start: content.x, spacing: columnSpacing)

        return items.map { item in
            guard item.isShown else { return nil }
            let values = item.values
            let margin = values.margin
            let row = min(max(values.row, 0), rowCount - 1)
            let column = min(max(values.column, 0), columnCount - 1)
            let rowEnd = min(row + max(values.rowSpan, 1), rowCount)
            let columnEnd = min(column + max(values.columnSpan, 1), columnCount)
            let cellWidth = columnSizes[column..<columnEnd].reduce(0, +)
                + columnSpacing * Double(max(columnEnd - column - 1, 0))
            let cellHeight = rowSizes[row..<rowEnd].reduce(0, +)
                + rowSpacing * Double(max(rowEnd - row - 1, 0))
            let availableWidth = max(0, cellWidth - margin.left - margin.right)
            let availableHeight = max(0, cellHeight - margin.top - margin.bottom)
            let natural = item.size(offered: availableWidth)
            let width = Extent.of(
                option: values.horizontal, stated: values.width, natural: natural.width,
                available: availableWidth, minimum: values.minimumWidth, maximum: values.maximumWidth)
            let height = Extent.of(
                option: values.vertical, stated: values.height, natural: natural.height,
                available: availableHeight, minimum: values.minimumHeight, maximum: values.maximumHeight)

            return Rect(
                x: Extent.start(
                    option: values.horizontal, extent: width,
                    start: columnOrigins[column] + margin.left, available: availableWidth),
                y: Extent.start(
                    option: values.vertical, extent: height,
                    start: rowOrigins[row] + margin.top, available: availableHeight),
                width: width,
                height: height)
        }
    }

    /// How many rows and columns the grid has: its definitions, or as many as its children reach.
    @MainActor
    private static func counts<Child: LayoutChild>(
        _ items: [Child], rows: [GridLength], columns: [GridLength]
    ) -> (rows: Int, columns: Int) {
        (max(rows.count, items.map { $0.values.row + $0.values.rowSpan }.max() ?? 1),
         max(columns.count, items.map { $0.values.column + $0.values.columnSpan }.max() ?? 1))
    }

    /// `definitions`, with a proportional track of one share for every track they do not define.
    private static func completed(_ definitions: [GridLength], count: Int) -> [GridLength] {
        definitions + Array(repeating: .proportional(1), count: max(0, count - definitions.count))
    }

    /// Each track's size: fixed as stated, automatic as its largest one-track child, proportional by share.
    /// A row measures each child at the width of the `columns` it stands in, where they are known.
    /// Design: docs/design/host/layout.md#tracks
    @MainActor
    private static func trackSizes<Child: LayoutChild>(
        _ items: [Child], definitions: [GridLength], count: Int,
        available: Double?, spacing: Double, vertical: Bool,
        columns: (sizes: [Double], spacing: Double)? = nil
    ) -> [Double] {
        var sizes = Array(repeating: 0.0, count: count)

        for index in 0..<count {
            if case .fixed(let length) = definitions[index] { sizes[index] = max(0, length) }
        }

        func extent(_ item: Child) -> Double {
            let margin = item.values.margin
            let measured = item.size(offered: columns.map { columns in
                let first = min(max(item.values.column, 0), columns.sizes.count - 1)
                let last = min(first + max(item.values.columnSpan, 1), columns.sizes.count)
                let cell = columns.sizes[first..<last].reduce(0, +)
                    + columns.spacing * Double(max(last - first - 1, 0))
                return max(0, cell - margin.left - margin.right)
            })
            return vertical
                ? measured.height + margin.top + margin.bottom
                : measured.width + margin.left + margin.right
        }

        func track(_ item: Child) -> (index: Int, span: Int) {
            vertical ? (item.values.row, item.values.rowSpan) : (item.values.column, item.values.columnSpan)
        }

        for item in items where item.isShown {
            let (index, span) = track(item)
            guard span == 1, index >= 0, index < count, definitions[index] == .auto else { continue }
            sizes[index] = max(sizes[index], extent(item))
        }

        let fixed = sizes.reduce(0, +) + spacing * Double(max(count - 1, 0))
        let starWeight = definitions.reduce(0.0) { weight, definition in
            if case .proportional(let share) = definition { return weight + max(share, 0.000_001) }
            return weight
        }
        let remainder = max(0, (available ?? fixed) - fixed)

        for index in 0..<count {
            guard case .proportional(let share) = definitions[index] else { continue }
            if available == nil {
                sizes[index] = items
                    .filter { track($0) == (index, 1) && $0.isShown }
                    .map(extent)
                    .max() ?? 0
            } else {
                sizes[index] = remainder * max(share, 0.000_001) / starWeight
            }
        }

        return sizes
    }

    /// Where each track starts, from `start`, with `spacing` between them.
    private static func origins(of sizes: [Double], start: Double, spacing: Double) -> [Double] {
        var answer: [Double] = []
        var cursor = start

        for size in sizes {
            answer.append(cursor)
            cursor += size + spacing
        }

        return answer
    }
}
