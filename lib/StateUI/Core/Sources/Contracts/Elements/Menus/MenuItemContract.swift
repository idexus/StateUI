// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One entry in a menu.
public enum MenuItemContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "MenuItem"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// An entry is an item a user chooses.
    public static let tiers: [any Contract.Type] = [MenuItemElementContract.self]

    /// Whether the entry stands checked - a mark beside it - for a setting choosing it turns on and off.
    public static let isOn = ElementProperty<Self, Bool>("isOn", layer: .native)

    /// The user chose an entry standing checked or not, turning it the other way: the way it turned to.
    public static let toggled = ElementEvent<Self, Bool>("toggled", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [isOn, toggled]
}
