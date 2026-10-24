// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a button that holds a menu has - a button's, a toolbar button's: how its menu opens, and whether the arrow
/// saying so shows.
public enum ButtonMenuElementContract: Contract {
    /// The tier's name.
    public static let name = "ButtonMenuElement"

    /// How the menu opens - by the click, an arrow, or held (`.menu`); a button is made anew when it changes.
    public static let menuKind = ElementProperty<Self, ButtonMenuKind>("menuKind", layer: .adaptive, remakes: true)

    /// Whether a button whose click opens its menu shows the arrow saying so; a button is made anew when it changes.
    public static let showsMenuArrow = ElementProperty<Self, Bool>("showsMenuArrow", layer: .native, remakes: true)

    /// The tier's own members.
    public static let members: [any ContractMember] = [menuKind, showsMenuArrow]
}
