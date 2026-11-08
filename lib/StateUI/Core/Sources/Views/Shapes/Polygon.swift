// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A closed outline through a list of points.
///
///     Polygon([Point(20, 0), Point(40, 40), Point(0, 40)])
///         .fill(.steelBlue)
///
/// The last point is joined back to the first,
/// which is the whole difference between this and a `Polyline`.
public struct Polygon: FilledShape, CorneredShape, PointsShape {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: PolygonContract.self)
    }

    /// The corners, in order.
    public init(_ points: [Point]) {
        node = Node(contract: PolygonContract.self)
        node.write(PointsShapeContract.points, points)
    }
}
