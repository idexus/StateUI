// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A native single-line text field.
public enum TextFieldContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "TextField"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A field is an input of text in a font, aligned.
    public static let tiers: [any Tier.Type] = [
        TextInputContract.self, TextualElementContract.self, FontElementContract.self,
        TextAlignmentElementContract.self, BorderElementContract.self,
        SubmitElementContract.self,
    ]

    /// Whether what is typed is hidden behind the platform's secure-entry
    /// marks.
    public static let isPassword = ElementProperty<Self, Bool>("isPassword", layer: .native)

    /// Whether the field shows the native button that empties it.
    public static let showsClearButton = ElementProperty<Self, Bool>("showsClearButton", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [isPassword, showsClearButton]
}
