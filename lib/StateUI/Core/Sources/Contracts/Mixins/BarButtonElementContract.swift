// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A button on a bar - an action or a setting: the press its visual states follow, beside the pointer over it every
/// item on a bar reports.
public enum BarButtonElementContract: Contract {
    /// The tier's name.
    public static let name = "BarButtonElement"

    /// A button on a bar is an item on it.
    public static let tiers: [any Contract.Type] = [BarItemElementContract.self]

    /// A press began on the button: a finger, a pen or a mouse button went down.
    public static let pressed = ElementEvent<Self, Void>("pressed", layer: .native)

    /// The press ended, wherever the pointer ended up.
    public static let released = ElementEvent<Self, Void>("released", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [pressed, released]
}
