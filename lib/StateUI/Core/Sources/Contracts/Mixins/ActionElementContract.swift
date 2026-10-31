// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What an item that acts has - a menu's entry, a toolbar's button: what choosing it does, and how the platform marks
/// it.
public enum ActionElementContract: Contract {
    /// The tier's name.
    public static let name = "ActionElement"

    /// An item that acts is found by automation.
    public static let tiers: [any Contract.Type] = [AutomationElementContract.self]

    /// The item was chosen.
    public static let clicked = ElementEvent<Self, Void>("clicked", layer: .native)

    /// What choosing the item does beyond its words: an ordinary action, or one that destroys something, which the
    /// platform marks.
    public static let role = ElementProperty<Self, ActionRole>("role", layer: .adaptive)

    /// The tier's own members.
    public static let members: [any ContractMember] = [clicked, role]
}
