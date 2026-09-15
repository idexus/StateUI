// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A box that is ticked or not.
public enum CheckBoxContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "CheckBox"

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A check box is a view, tinted.
    public static let tiers: [any Contract.Type] = [ViewContract.self, TintElementContract.self]

    /// Whether the box is ticked.
    public static let isOn = ElementProperty<Self, Bool>("isOn", layer: .native)

    /// The box was ticked or unticked, to the value it carries.
    public static let toggled = ElementEvent<Self, Bool>("toggled", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [isOn, toggled]
}
