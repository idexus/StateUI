// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Whatever an outline can be, written in SVG path syntax.
public enum PathContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .path

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A path is a shape.
    public static let tiers: [any Contract.Type] = [ShapeContract.self]

    /// The outline, in SVG path syntax.
    public static let data = ElementProperty<Self, String>("data", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [data]
}
