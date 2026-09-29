// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A grid of items as wide as it is given: as many columns as hold items at least the narrowest width, the columns
/// sharing what is left once the spacing between them is taken.
/// Design: docs/design/host/items.md#a-grid
@_spi(Host) public enum ItemsGrid {
    /// How many columns `width` holds for items at least `minimumItemWidth` wide, `spacing` apart - one at least.
    public static func columns(width: Double, minimumItemWidth: Double, spacing: Double) -> Int {
        guard width > 0, minimumItemWidth > 0 else { return 1 }
        return max(1, Int(((width + spacing) / (minimumItemWidth + spacing)).rounded(.down)))
    }

    /// How wide each of `columns` columns stands in `width`, `spacing` apart.
    public static func columnWidth(width: Double, columns: Int, spacing: Double) -> Double {
        let count = Double(max(columns, 1))
        return max(0, (width - spacing * (count - 1)) / count)
    }
}
