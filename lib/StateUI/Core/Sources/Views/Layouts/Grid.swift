// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Grid`'s own properties, shared by the control and its `Style<Grid>`.
public protocol GridProperties: PropertyContainer {}

extension GridProperties {
    /// How tall each row is - one length per row, or a run of rows alike with a
    /// count, so together they say how many rows there are.
    ///
    ///     .rows(.fill, .auto(count: 2), .fill(count: 5), .fixed(80))
    ///
    /// `.auto` fits what is in the row, `.fill` and `.proportional` take a
    /// share of what is left over, and `.fixed` is that many device units. A
    /// grid told nothing has one row and one column.
    public func rows(_ runs: GridTracks...) -> Modified {
        setValue(GridContract.rows, GridTracks.lengths(runs))
    }

    /// How wide each column is - one length per column, or a run of columns
    /// alike with a count, so together they say how many columns there are.
    ///
    ///     .columns(.fill(count: 4))
    ///
    /// The same kinds of length as `rows`.
    public func columns(_ runs: GridTracks...) -> Modified {
        setValue(GridContract.columns, GridTracks.lengths(runs))
    }

    /// The gap between one row and the next, in device units - between the rows
    /// only; the space around the whole grid is `.padding`.
    public func rowSpacing(_ value: Double) -> Modified {
        setValue(GridContract.rowSpacing, value)
    }

    /// The gap between one column and the next, in device units.
    public func columnSpacing(_ value: Double) -> Modified {
        setValue(GridContract.columnSpacing, value)
    }
}

/// Arranges its children in rows and columns.
///
///     Grid {
///         Text("Column 0, Row 0")
///
///         Text("Column 1, Row 0")
///             .gridColumn(1)
///
///         Text("Spanning both")
///             .gridRow(1)
///             .gridColumnSpan(2)
///     }
///     .rows(.auto, .fill)
///     .columns(.fill, .proportional(2))
///     .rowSpacing(12)
///     .columnSpacing(12)
///
/// Where a child sits is written on the child, with `.gridRow` and
/// `.gridColumn`.
///
/// A child that says nothing sits in row 0, column 0 - which is how two
/// children end up on top of one another if that was not intended.
public struct Grid: Layout, GridProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Grid>` is written against.
    public init() {
        node = Node(contract: GridContract.self)
    }

    /// A grid holding what the closure describes. The closure runs when the
    /// differ reaches the grid.
    public init<Content: Views>(@ViewBuilder content: @escaping () -> Content) {
        node = Node(contract: GridContract.self)
        node.producer = { content().nodes }
    }

}

extension Grid {
    /// `columnSpacing` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func columnSpacing(_ state: Binding<Double>) -> Modified {
        twin(GridContract.columnSpacing, by: state)
    }

    /// `rowSpacing` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func rowSpacing(_ state: Binding<Double>) -> Modified {
        twin(GridContract.rowSpacing, by: state)
    }
}
