// MAUI: Polyline.

/// Polyline's own properties - the half a `Style<Polyline>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol PolylineProperties: PropertyContainer {}

extension PolylineProperties {
    /// The points, in order, left OPEN - the last is not joined back to the
    /// first. MAUI: Polyline.Points.
    ///
    ///     Polyline().points([Point(0, 30), Point(20, 5), Point(40, 25)])
    ///
    /// The numbers are device units in the shape's OWN space, which `.aspect`
    /// then fits to the room the layout gives it. They travel as the pairs
    /// themselves - x, y, x, y - which the host makes a `PointCollection` of.
    public func points(_ value: [Point]) -> Modified {
        setValue(.points, value.propValue)
    }

    /// Which parts of a self-crossing outline count as inside it, and so get
    /// painted by `fill`. MAUI: Polyline.FillRule.
    ///
    /// Only the fill looks at it; the line itself is drawn the same either
    /// way. An open line still has an inside: a filled polyline is painted as
    /// though the last point were joined back to the first, with that join
    /// left undrawn. So this matters on a FILLED line whose path crosses
    /// itself, and nowhere else.
    public func fillRule(_ value: FillRule) -> Modified {
        setValue(.fillRule, value.propValue)
    }
}

/// An open outline through a list of points - a chart line, a signature, a
/// zigzag.
///
///     Polyline([Point(0, 30), Point(20, 5), Point(40, 25), Point(60, 0)])
///         .stroke(.cornflowerBlue)
///         .strokeThickness(2)
///
/// The same list a `Polygon` takes, left open: the last point is not joined back
/// to the first. It still has an inside that `fill` paints, decided the way a
/// polygon's is.
public struct Polyline: Shape, PolylineProperties {
    /// The node this control describes.
    public var node: Node

    /// A polyline with no points yet - what a `Style<Polyline>` is written
    /// against.
    public init() {
        node = Node(type: .polyline)
    }

    /// The points, in order. The value that gives a polyline its purpose.
    public init(_ points: [Point]) {
        node = Node(type: .polyline, props: [.points: points.propValue])
    }

}
