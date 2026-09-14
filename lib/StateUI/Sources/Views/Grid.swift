// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Grid's own properties - the half a `Style<Grid>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol GridProperties: PropertyContainer {}

extension GridProperties {
    /// How tall each row is - one length per row, so the count says how many
    /// rows there are.
    ///
    ///     .rows(.auto, .fill, .proportional(2), .fixed(100))
    ///
    /// `.auto` fits what is in the row, `.fill` takes a share of what is left
    /// over, and `.absolute` is that many device units. A grid told nothing has
    /// one row and one column.
    public func rows(_ lengths: GridLength...) -> Modified {
        setValue(.rows, lengths.propValue)
    }

    /// How wide each column is - one length per column, so the count says how
    /// many columns there are.
    ///
    ///     .columns(.fill, .proportional(2))
    ///
    /// The same three kinds of length as `rows`.
    public func columns(_ lengths: GridLength...) -> Modified {
        setValue(.columns, lengths.propValue)
    }

    /// The gap between one row and the next, in device units. It falls
    /// BETWEEN the rows only - the space around the whole grid is `.padding`.
    public func rowSpacing(_ value: Double) -> Modified {
        setValue(.rowSpacing, .number(value))
    }

    /// The gap between one column and the next, in device units.
    public func columnSpacing(_ value: Double) -> Modified {
        setValue(.columnSpacing, .number(value))
    }
}

/// Arranges its children in rows and columns.
///
///     Grid {
///         Label("Column 0, Row 0")
///
///         Label("Column 1, Row 0")
///             .gridColumn(1)
///
///         Label("Spanning both")
///             .gridRow(1)
///             .gridColumnSpan(2)
///     }
///     .rows(.auto, .fill)
///     .columns(.fill, .proportional(2))
///     .rowSpacing(12)
///     .columnSpacing(12)
///
/// Where a child sits is written on the CHILD, with `.gridRow` and
/// `.gridColumn`. Those modifiers are on View, because any view can be a grid
/// child; see Elements.swift.
///
/// A child that says nothing sits in row 0, column 0 - which is how two
/// children end up on top of one another if that was not intended.
public struct Grid: Layout, GridProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Grid>` is written against.
    public init() {
        node = Node(type: .grid)
    }

    /// A grid holding what the closure describes. Where each child sits is
    /// written on the child, with `.gridRow` and `.gridColumn`.
    ///
    /// The closure is KEPT, not run: the children are described when the
    /// differ reaches this grid, so a grid inside a carried view costs
    /// nothing and an ancestor's `.environment(...)` is in scope for
    /// whatever the closure builds.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(type: .grid)
        node.producer = { content().map { $0.body } }
    }

}
