// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Polyline`'s own properties, shared by the control and its
/// `Style<Polyline>`.
public protocol PolylineProperties: PropertyContainer {}

extension PolylineProperties {
    /// The points, in order, left open - the last is not joined back to the
    /// first.
    ///
    ///     Polyline().points([Point(0, 30), Point(20, 5), Point(40, 25)])
    ///
    /// The numbers are device units in the shape's own space, which `.aspect`
    /// fits to the room the layout gives it.
    public func points(_ value: [Point]) -> Modified {
        setValue(PolylineContract.points, value)
    }

    /// Which parts of a self-crossing outline count as inside it, and so get
    /// painted by `fill`.
    ///
    /// A filled polyline is painted as though its last point were joined back
    /// to the first, so this matters only on a filled line that crosses itself.
    public func fillRule(_ value: FillRule) -> Modified {
        setValue(PolylineContract.fillRule, value)
    }
}

/// An open outline through a list of points - a chart line, a signature, a
/// zigzag.
///
///     Polyline([Point(0, 30), Point(20, 5), Point(40, 25), Point(60, 0)])
///         .stroke(.cornflowerBlue)
///         .strokeWidth(2)
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
        node = Node(contract: PolylineContract.self)
    }

    /// The points, in order.
    public init(_ points: [Point]) {
        node = Node(contract: PolylineContract.self)
        node.write(PolylineContract.points, points)
    }

}
