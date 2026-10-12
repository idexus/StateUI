// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An element that takes the keyboard focus itself - a field, a button, a list - and so holds the keyboard.
public enum FocusElementContract: Contract {
    /// The tier's name.
    public static let name = "FocusElement"

    /// What takes the focus holds the keyboard.
    public static let tiers: [any Contract.Type] = [KeyboardElementContract.self]

    /// Gives the element the keyboard focus, answering whether it took it.
    public static let focus = ElementAct<Self, Void, Bool>("focus")

    /// The platform moved the focus onto the element, or off it.
    public static let isFocusedChanged = ElementEvent<Self, Bool>("isFocusedChanged", layer: .native)

    /// Takes the keyboard focus off the element.
    public static let unfocus = ElementAct<Self, Void, Void>("unfocus")

    /// The tier's own members.
    public static let members: [any ContractMember] = [focus, isFocusedChanged, unfocus]
}
