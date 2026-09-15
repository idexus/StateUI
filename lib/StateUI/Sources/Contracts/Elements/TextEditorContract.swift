// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A text field of several lines.
public enum TextEditorContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = .textEditor

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// An editor is an input of text in a font, aligned.
    public static let tiers: [any Contract.Type] = [
        InputViewContract.self, TextElementContract.self, FontElementContract.self,
        TextAlignmentElementContract.self,
    ]

    /// Whether the editor grows as the text does.
    public static let growsWithText = ElementProperty<Self, Bool>("growsWithText", layer: .native)

    /// The element's own members.
    public static let members: [any ContractMember] = [growsWithText]
}
