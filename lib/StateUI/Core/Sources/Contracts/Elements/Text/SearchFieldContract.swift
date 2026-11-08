// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A text field for what to search for, shown as the platform's search field.
public enum SearchFieldContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "SearchField"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A search field is an input of text in a font, aligned.
    public static let tiers: [any Tier.Type] = [
        TextInputContract.self, TextualElementContract.self, FontElementContract.self,
        TextAlignmentElementContract.self, BorderElementContract.self,
        SubmitElementContract.self,
    ]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
