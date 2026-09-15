// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A straight line between two points, in device units from the top left of the
/// space the line is given.
public enum LineContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .line

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A line is a shape.
    public static let tiers: [any Contract.Type] = [ShapeContract.self]

    /// Where it starts, across.
    public static let x1 = ElementProperty<Self, Double>("x1", layer: .stateUI)

    /// Where it ends, across.
    public static let x2 = ElementProperty<Self, Double>("x2", layer: .stateUI)

    /// Where it starts, down.
    public static let y1 = ElementProperty<Self, Double>("y1", layer: .stateUI)

    /// Where it ends, down.
    public static let y2 = ElementProperty<Self, Double>("y2", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [x1, x2, y1, y2]
}
