// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An open outline through a list of points - a chart line, a signature, a
/// zigzag.
public enum PolylineContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Polyline"

    /// StateUI decides its geometry, its arrangement or its composition; a host
    /// draws what was decided.
    public static let layer: ElementLayer = .stateUI

    /// A polyline is a shape.
    public static let tiers: [any Tier.Type] = [FilledShapeContract.self, CorneredShapeContract.self, PointsShapeContract.self]

    /// The element's own members: none beyond its tiers'.
    public static let members: [any ContractMember] = []
}
