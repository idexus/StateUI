// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Where a row of an arrangement's own - a tabbed view's tabs - stands beside its page, the same on every host: across
/// the top or across the bottom, the page taking the rest of the room.
/// Design: docs/design/host/layout.md#a-row-beside-a-page
@_spi(Host) public enum RowEdge: Sendable {
    /// Across the top of the room.
    case top

    /// Across the bottom of the room.
    case bottom

    /// The row `height` tall at this edge of `bounds`, and the room the page has beside it, never less than none.
    public func split(_ bounds: Rect, row height: Double) -> (row: Rect, page: Rect) {
        let row = min(max(height, 0), bounds.height)
        let rest = bounds.height - row
        return switch self {
        case .top:
            (Rect(x: bounds.x, y: bounds.y, width: bounds.width, height: row),
             Rect(x: bounds.x, y: bounds.y + row, width: bounds.width, height: rest))
        case .bottom:
            (Rect(x: bounds.x, y: bounds.y + rest, width: bounds.width, height: row),
             Rect(x: bounds.x, y: bounds.y, width: bounds.width, height: rest))
        }
    }

    /// The size a page of `page` size takes with a row `height` tall beside it.
    public static func size(page: LayoutSize, row height: Double) -> LayoutSize {
        LayoutSize(width: page.width, height: page.height + max(height, 0))
    }
}
