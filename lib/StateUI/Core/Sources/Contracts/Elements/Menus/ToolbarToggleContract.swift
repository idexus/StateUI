// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A setting on the page's bar, standing on or off - a two-state button.
public enum ToolbarToggleContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ToolbarToggle"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// A setting on the bar is an item a user chooses.
    public static let tiers: [any Contract.Type] = [MenuItemElementContract.self, TextAndIconElementContract.self]

    /// Whether it stands on.
    public static let isOn = ElementProperty<Self, Bool>("isOn", layer: .native)

    /// The picture it shows while on, in place of its own; unwritten, its own picture both ways.
    public static let onIcon = ElementProperty<Self, ImageSource>("onIcon", layer: .adaptive)

    /// The user chose it, turning it the other way: the way it turned to.
    public static let toggled = ElementEvent<Self, Bool>("toggled", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [isOn, onIcon, toggled]
}
