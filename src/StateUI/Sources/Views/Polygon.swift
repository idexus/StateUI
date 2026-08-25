// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Polygon.

/// Polygon's own properties - the half a `Style<Polygon>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol PolygonProperties: PropertyContainer {}

extension PolygonProperties {
    /// The corners, in order, joined last back to first.
    /// MAUI: Polygon.Points.
    ///
    ///     Polygon().points([Point(20, 0), Point(40, 40), Point(0, 40)])
    ///
    /// The numbers are device units in the shape's OWN space, which `.aspect`
    /// then fits to the room the layout gives it. They travel as the pairs
    /// themselves - x, y, x, y - which the host makes a `PointCollection` of.
    public func points(_ value: [Point]) -> Modified {
        setValue(.points, value.propValue)
    }

    /// Which parts of a self-crossing outline count as inside it, and so get
    /// painted by `fill`. MAUI: Polygon.FillRule.
    ///
    /// Only the fill looks at it; the outline is drawn the same either way.
    /// The choice shows on a shape whose edges cross - a five-pointed star,
    /// where `.evenOdd` leaves the middle hollow and `.nonzero` fills it.
    public func fillRule(_ value: FillRule) -> Modified {
        setValue(.fillRule, value.propValue)
    }
}

/// A closed outline through a list of points.
///
///     Polygon([Point(20, 0), Point(40, 40), Point(0, 40)])
///         .fill(.solidColor(.steelBlue))
///
/// MAUI closes the figure for you - the last point is joined back to the first,
/// which is the whole difference between this and a `Polyline`.
public struct Polygon: Shape, PolygonProperties {
    /// The node this control describes.
    public var node: Node

    /// A polygon with no points yet - what a `Style<Polygon>` is written
    /// against.
    public init() {
        node = Node(type: .polygon)
    }

    /// The corners, in order. The value that gives a polygon its purpose.
    public init(_ points: [Point]) {
        node = Node(type: .polygon, props: [.points: points.propValue])
    }
}
