// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a control the user chooses reports: a button, a link, a menu's entry, a toolbar's button.
public enum ClickElementContract: Tier {
    /// The tier's own name.
    public static let name = "ClickElement"

    /// The user chose it: a click, a tap, the keyboard.
    public static let clicked = ElementEvent<Self, Void>("clicked", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [clicked]
}
