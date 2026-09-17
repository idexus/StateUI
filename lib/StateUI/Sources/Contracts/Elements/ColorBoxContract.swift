// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A host-native rectangle of colour.
public enum ColorBoxContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ColorBox"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A box is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// What the rectangle is filled with.
    public static let color = ElementProperty<Self, Color>("color", layer: .native)

    /// How rounded the corners are: one radius for all four, or one each.
    public static let cornerRadius = ElementProperty<Self, CornerRadius>(
        "cornerRadius", layer: .native, moves: .size)

    /// The element's own members.
    public static let members: [any ContractMember] = [color, cornerRadius]
}
