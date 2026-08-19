// MAUI: Line.

/// A straight line between two points, in device units from the top left of the
/// space the line is given.
///
///     Line()
///         .x1(0).y1(0)
///         .x2(240).y2(0)
///         .stroke(.lightGray)
///         .strokeThickness(1)
///
/// A line with no stroke draws nothing: it has no inside for `fill` to paint.
///
/// Each coordinate left unsaid is 0, as it is in MAUI, so `.x2(240)` on its own
/// runs from the top left corner across. The four are modifiers rather than
/// arguments for the reason every property here is one - only what gives a
/// control its purpose goes in the initializer, and a line's purpose is not any
/// one of the four.
public struct Line: Shape, LineProperties {
    /// The node this control describes.
    public var node: Node

    /// A line with nothing set - what a `Style<Line>` is written against.
    public init() {
        node = Node(type: .line)
    }
}

/// Line's own properties - the half a `Style<Line>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol LineProperties: PropertyContainer {}

extension LineProperties {
    /// Where it starts, across. MAUI: Line.X1.
    public func x1(_ value: Double) -> Modified { setValue(.x1, .number(value)) }

    /// Where it starts, down. MAUI: Line.Y1.
    public func y1(_ value: Double) -> Modified { setValue(.y1, .number(value)) }

    /// Where it ends, across. MAUI: Line.X2.
    public func x2(_ value: Double) -> Modified { setValue(.x2, .number(value)) }

    /// Where it ends, down. MAUI: Line.Y2.
    public func y2(_ value: Double) -> Modified { setValue(.y2, .number(value)) }
}
