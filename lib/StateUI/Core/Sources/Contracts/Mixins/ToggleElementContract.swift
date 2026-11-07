// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control turned on and off holds and reports: a check box, a switch, a menu's and a toolbar's toggle.
public enum ToggleElementContract: Tier {
    /// The tier's own name.
    public static let name = "ToggleElement"

    /// Whether it is on.
    public static let isOn = ElementProperty<Self, Bool>("isOn", layer: .native)

    /// The user turned it, to the position it carries.
    public static let toggled = ElementEvent<Self, Bool>("toggled", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [isOn, toggled]
}
