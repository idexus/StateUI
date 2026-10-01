// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One choice out of a list.
public enum PickerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Picker"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A picker is a view of text in a font, aligned and tinted.
    public static let tiers: [any Contract.Type] = [
        ViewContract.self, TextStyleElementContract.self, FontElementContract.self,
        TextAlignmentElementContract.self, TintElementContract.self,
    ]

    /// The user has closed the list of choices.
    public static let closed = ElementEvent<Self, Void>("closed", layer: .native)

    /// Whether the list of choices is showing.
    public static let isOpen = ElementProperty<Self, Bool>("isOpen", layer: .native)

    /// The user has opened the list of choices.
    public static let opened = ElementEvent<Self, Void>("opened", layer: .native)

    /// The list to choose from, in the order it is offered.
    public static let options = ElementProperty<Self, [String]>("options", layer: .structure, cleared: false)

    /// Which item is chosen, counted from zero; -1 for none.
    public static let selectedIndex = ElementProperty<Self, Int>(
        "selectedIndex", layer: .native, travels: false, cleared: false)

    /// The user changed the choice, to the index it carries.
    public static let selectedIndexChanged = ElementEvent<Self, Int>("selectedIndexChanged", layer: .native)

    /// What the field says while nothing is chosen.
    public static let title = ElementProperty<Self, String>("title", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        closed, isOpen, opened, options, selectedIndex, selectedIndexChanged, title,
    ]
}
