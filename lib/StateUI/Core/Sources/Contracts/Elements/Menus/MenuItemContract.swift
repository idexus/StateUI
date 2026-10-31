// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One entry in a menu.
public enum MenuItemContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "MenuItem"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// An entry is an item a user chooses, and it acts.
    public static let tiers: [any Contract.Type] = [MenuItemElementContract.self, ActionElementContract.self]

    /// The element's own members: none beyond its tiers'.
    public static let members: [any ContractMember] = []
}
