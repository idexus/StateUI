// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One run of text inside a label, with its own color, size and weight.
public enum TextSpanContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "TextSpan"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// A run is text in a font, decorated - and no view: no line of its own, and nothing automation finds.
    public static let tiers: [any Tier.Type] = [
        TextualElementContract.self, FontElementContract.self, TrackingElementContract.self,
        DecorableTextElementContract.self,
        BackgroundElementContract.self,
    ]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
