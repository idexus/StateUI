// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One choice out of a list.
public enum PickerContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Picker"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A picker is a view of text in a font, aligned and tinted.
    public static let tiers: [any Tier.Type] = [
        ViewContract.self, TextColorElementContract.self, FontElementContract.self,
        TextAlignmentElementContract.self, TintElementContract.self, FocusElementContract.self,
        PopupElementContract.self,
        PlaceholderElementContract.self,
    ]

    /// The list to choose from, in the order it is offered.
    public static let options = ElementProperty<Self, [String]>("options", layer: .structure, cleared: false)

    /// How the values are offered: a menu, segments or radio buttons. Another
    /// value makes the picker anew - each is another control.
    public static let presentation = ElementProperty<Self, PickerPresentation>(
        "presentation", layer: .native, remakes: true)

    /// Which item is chosen, counted from zero; -1 for none.
    public static let selectedIndex = ElementProperty<Self, Int>(
        "selectedIndex", layer: .native, travels: false, cleared: false)

    /// The user changed the choice, to the index it carries.
    public static let selectedIndexChanged = ElementEvent<Self, Int>("selectedIndexChanged", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [options, presentation, selectedIndex, selectedIndexChanged]
}
