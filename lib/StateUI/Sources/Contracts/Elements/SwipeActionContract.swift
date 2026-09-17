// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One thing a swipe reveals.
public enum SwipeActionContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "SwipeAction"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// An action is an item a reader chooses.
    public static let tiers: [any Contract.Type] = [MenuItemElementContract.self]

    /// What is drawn behind it, which tells one action from the next.
    public static let background = ElementProperty<Self, Color>("background", layer: .native)

    /// Whether it is revealed at all.
    public static let isVisible = ElementProperty<Self, Bool>("isVisible", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [background, isVisible]
}
