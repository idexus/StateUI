// MAUI: Grid.

/// Grid's own properties - the half a `Style<Grid>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol GridProperties: PropertyContainer {}

extension GridProperties {
    /// How tall each row is - one length per row, so the count says how many
    /// rows there are. MAUI: Grid.RowDefinitions.
    ///
    ///     .rowDefinitions(.auto, .star, .star(2), .absolute(100))
    ///
    /// `.auto` fits what is in the row, `.star` takes a share of what is left
    /// over, and `.absolute` is that many device units. A grid told nothing has
    /// one row and one column, as MAUI's does.
    public func rowDefinitions(_ lengths: GridLength...) -> Modified {
        setValue(.rowDefinitions, lengths.propValue)
    }

    /// How wide each column is - one length per column, so the count says how
    /// many columns there are. MAUI: Grid.ColumnDefinitions.
    ///
    ///     .columnDefinitions(.star, .star(2))
    ///
    /// The same three kinds of length as `rowDefinitions`.
    public func columnDefinitions(_ lengths: GridLength...) -> Modified {
        setValue(.columnDefinitions, lengths.propValue)
    }

    /// The gap between one row and the next, in device units.
    /// MAUI: Grid.RowSpacing. It falls BETWEEN the rows only - the space
    /// around the whole grid is `.padding`.
    public func rowSpacing(_ value: Double) -> Modified {
        setValue(.rowSpacing, .number(value))
    }

    /// The gap between one column and the next, in device units.
    /// MAUI: Grid.ColumnSpacing.
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
///     .rowDefinitions(.auto, .star)
///     .columnDefinitions(.star, .star(2))
///     .rowSpacing(12)
///     .columnSpacing(12)
///
/// Where a child sits is written on the CHILD, as in XAML - `Grid.Row="1"` is
/// `.gridRow(1)`. Those modifiers are on View, because any view can be a grid
/// child; see Elements.swift.
///
/// A child that says nothing sits in row 0, column 0, which is MAUI's default
/// and how two children end up on top of one another if that was not intended.
public struct Grid: Layout, GridProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Grid>` is written against.
    public init() {
        node = Node(type: .grid)
    }

    /// A grid holding what the closure describes. Where each child sits is
    /// written on the child, with `.gridRow` and `.gridColumn`.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .grid, children: content().map { $0.body })
    }

}
