// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A grid of items as wide as it is given: as many columns as hold items at least the narrowest width, the columns
/// sharing what is left once the spacing between them is taken.
/// Design: docs/design/host/items.md#a-grid
@_spi(Host) public enum ItemsGrid {
    /// How many columns `width` holds for items at least `minimumItemWidth` wide, `spacing` apart - one at least,
    /// none narrower than a point, whatever the numbers.
    public static func columns(width: Double, minimumItemWidth: Double, spacing: Double) -> Int {
        guard width.isFinite, width > 0, minimumItemWidth > 0 else { return 1 }
        let spacing = ItemsLayout.length(spacing)
        let fit = min(((width + spacing) / (minimumItemWidth + spacing)).rounded(.down), width.rounded(.down))
        return fit >= 2 ? Int(min(fit, Double(Int32.max))) : 1
    }

    /// How wide each of `columns` columns stands in `width`, `spacing` apart.
    public static func columnWidth(width: Double, columns: Int, spacing: Double) -> Double {
        let count = Double(max(columns, 1))
        return max(0, (width - ItemsLayout.length(spacing) * (count - 1)) / count)
    }
}
