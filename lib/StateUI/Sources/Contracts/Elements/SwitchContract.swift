// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An on/off toggle.
public enum SwitchContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .`switch`

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A switch is a view, tinted.
    public static let tiers: [any Contract.Type] = [ViewContract.self, TintElementContract.self]

    /// Which way it is thrown - true for on.
    public static let isOn = ElementProperty<Self, Bool>("isOn", layer: .native)

    /// It was flipped, to the value it carries.
    public static let toggled = ElementEvent<Self, Bool>("toggled", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [isOn, toggled]
}
