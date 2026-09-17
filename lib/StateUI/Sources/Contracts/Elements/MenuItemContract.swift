// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One entry in a menu.
public enum MenuItemContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "MenuItem"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// An entry is an item a reader chooses.
    public static let tiers: [any Contract.Type] = [MenuItemElementContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
