// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A rectangle, drawn as a shape - with square corners, or rounded ones.
public enum RectangleContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .rectangle

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A rectangle is a shape.
    public static let tiers: [any Contract.Type] = [ShapeContract.self]

    /// How rounded the corners are: one radius for all four, or one each.
    public static let cornerRadius = ElementProperty<Self, CornerRadius>(
        "cornerRadius", layer: .native, moves: .size)

    /// The element's own members.
    public static let members: [any ContractMember] = [cornerRadius]
}
