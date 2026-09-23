// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Polygon`'s own properties, shared by the control and its `Style<Polygon>`.
public protocol PolygonProperties: PropertyContainer {}

extension PolygonProperties {
    /// The corners, in order, joined last back to first.
    ///
    ///     Polygon().points([Point(20, 0), Point(40, 40), Point(0, 40)])
    ///
    /// The numbers are device units in the shape's own space, which `.aspect`
    /// fits to the room the layout gives it.
    public func points(_ value: [Point]) -> Modified {
        setValue(PolygonContract.points, value)
    }

    /// Which parts of a self-crossing outline count as inside it, and so get
    /// painted by `fill`.
    ///
    /// Only the fill looks at it; the outline is drawn the same either way.
    /// The choice shows on a shape whose edges cross - a five-pointed star,
    /// where `.evenOdd` leaves the middle hollow and `.nonzero` fills it.
    public func fillRule(_ value: FillRule) -> Modified {
        setValue(PolygonContract.fillRule, value)
    }
}

/// A closed outline through a list of points.
///
///     Polygon([Point(20, 0), Point(40, 40), Point(0, 40)])
///         .fill(.solidColor(.steelBlue))
///
/// The last point is joined back to the first,
/// which is the whole difference between this and a `Polyline`.
public struct Polygon: Shape, PolygonProperties {
    /// The node this control describes.
    public var node: Node

    /// A polygon with no points yet - what a `Style<Polygon>` is written
    /// against.
    public init() {
        node = Node(contract: PolygonContract.self)
    }

    /// The corners, in order.
    public init(_ points: [Point]) {
        node = Node(contract: PolygonContract.self)
        node.write(PolygonContract.points, points)
    }
}

extension Polygon {
    /// `fillRule` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func fillRule(_ state: Binding<FillRule>) -> Modified {
        plain(PolygonContract.fillRule.token, by: state)
    }
}
