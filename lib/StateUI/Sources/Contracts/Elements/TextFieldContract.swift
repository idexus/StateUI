// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A native single-line text field.
public enum TextFieldContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .textField

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A field is an input of text in a font, aligned.
    public static let tiers: [any Contract.Type] = [
        InputViewContract.self, TextElementContract.self, FontElementContract.self,
        TextAlignmentElementContract.self,
    ]

    /// Whether what is typed is hidden behind the platform's secure-entry
    /// marks.
    public static let isPassword = ElementProperty<Self, Bool>("isPassword", layer: .native)

    /// What the keyboard's return key is captioned.
    public static let returnKey = ElementProperty<Self, ReturnKey>("returnKey", layer: .adaptive)

    /// Whether the field shows the native button that empties it.
    public static let showsClearButton = ElementProperty<Self, Bool>("showsClearButton", layer: .adaptive)

    /// The return key was pressed.
    public static let submitted = ElementEvent<Self, Void>("submitted", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [isPassword, returnKey, showsClearButton, submitted]
}
