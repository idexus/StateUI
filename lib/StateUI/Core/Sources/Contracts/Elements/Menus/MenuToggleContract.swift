// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One entry in a menu standing checked or not - a setting choosing it turns on and off.
public enum MenuToggleContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "MenuToggle"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// A setting's entry is an item a user chooses.
    public static let tiers: [any Tier.Type] = [
        AutomationElementContract.self, EnabledElementContract.self, IconElementContract.self,
        ShortcutElementContract.self, TextElementContract.self, ToggleElementContract.self,
    ]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
