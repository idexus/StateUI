// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An open outline through a list of points - a chart line, a signature, a
/// zigzag.
public enum PolylineContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .polyline

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A polyline is a shape.
    public static let tiers: [any Contract.Type] = [ShapeContract.self]

    /// Which parts of a self-crossing outline count as inside it.
    public static let fillRule = ElementProperty<Self, FillRule>("fillRule", layer: .stateUI)

    /// The points, in order, left open.
    public static let points = ElementProperty<Self, [Point]>("points", layer: .stateUI, travels: false)

    /// The element's own members.
    public static let members: [any ContractMember] = [fillRule, points]
}
