// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One run of text inside a label, with its own colour, size and weight.
public enum TextSpanContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "TextSpan"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// A run is text in a font, spaced and decorated - and no view.
    public static let tiers: [any Contract.Type] = [
        TextualElementContract.self, FontElementContract.self, LineHeightElementContract.self,
        DecorableTextElementContract.self,
    ]

    /// What is drawn behind the run - a highlight over part of a line.
    public static let background = ElementProperty<Self, Material>("background", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [background]
}
