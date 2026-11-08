// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A closed outline through a list of points.
public enum PolygonContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Polygon"

    /// StateUI decides its geometry, its arrangement or its composition; a host
    /// draws what was decided.
    public static let layer: ElementLayer = .stateUI

    /// A polygon is a shape.
    public static let tiers: [any Tier.Type] = [FilledShapeContract.self, CorneredShapeContract.self, PointsShapeContract.self]

    /// The element's own members: none beyond its tiers'.
    public static let members: [any ContractMember] = []
}
