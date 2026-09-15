// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One choice out of several, where picking one clears the rest.
public enum RadioButtonContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .radioButton

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A radio button is a view with a caption in a font, padded and bordered.
    public static let tiers: [any Contract.Type] = [
        ViewContract.self, TextElementContract.self, FontElementContract.self, PaddingElementContract.self,
        BorderElementContract.self,
    ]

    /// Which set it belongs to: picking one clears every other button of the
    /// same name in its window.
    public static let groupName = ElementProperty<Self, Name>("groupName", layer: .stateUI)

    /// Whether this is the chosen one.
    public static let isOn = ElementProperty<Self, Bool>("isOn", layer: .native)

    /// The button was picked or cleared, to the value it carries.
    public static let toggled = ElementEvent<Self, Bool>("toggled", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [groupName, isOn, toggled]
}
