// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A menu: a caption and the entries it opens - on the menu bar, or one level
/// down inside another menu.
public enum MenuContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Menu"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The tiers it wears.
    public static let tiers: [any Tier.Type] = [EnabledElementContract.self, TextElementContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
