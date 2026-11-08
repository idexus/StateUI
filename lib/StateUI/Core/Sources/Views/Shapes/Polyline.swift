// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An open outline through a list of points - a chart line, a signature, a
/// zigzag.
///
///     Polyline([Point(0, 30), Point(20, 5), Point(40, 25), Point(60, 0)])
///         .stroke(.cornflowerBlue)
///         .lineWidth(2)
///
/// The same list a `Polygon` takes, left open: the last point is not joined back
/// to the first. It still has an inside that `fill` paints, decided the way a
/// polygon's is.
public struct Polyline: FilledShape, CorneredShape, PointsShape {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: PolylineContract.self)
    }

    /// The points, in order.
    public init(_ points: [Point]) {
        node = Node(contract: PolylineContract.self)
        node.write(PointsShapeContract.points, points)
    }
}
