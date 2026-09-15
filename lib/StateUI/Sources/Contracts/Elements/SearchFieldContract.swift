// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A text field with a search button on the keyboard.
public enum SearchFieldContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .searchField

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A search field is an input of text in a font, aligned and tinted.
    public static let tiers: [any Contract.Type] = [
        InputViewContract.self, TextElementContract.self, FontElementContract.self,
        TextAlignmentElementContract.self, TintElementContract.self,
    ]

    /// What the keyboard's return key is captioned.
    public static let returnKey = ElementProperty<Self, ReturnKey>("returnKey", layer: .adaptive)

    /// The search was submitted.
    public static let submitted = ElementEvent<Self, Void>("submitted", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [returnKey, submitted]
}
