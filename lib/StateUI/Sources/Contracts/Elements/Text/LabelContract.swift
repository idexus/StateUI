// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A read-only piece of text.
public enum LabelContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Label"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A label is a view of text in a font - aligned, spaced, decorated and
    /// padded.
    public static let tiers: [any Contract.Type] = [
        ViewContract.self, TextElementContract.self, FontElementContract.self,
        TextAlignmentElementContract.self, LineHeightElementContract.self, DecorableTextElementContract.self,
        PaddingElementContract.self,
    ]

    /// What happens to text too long for the space: it wraps, or it is cut and
    /// says so.
    public static let lineBreak = ElementProperty<Self, LineBreak>("lineBreak", layer: .native)

    /// How many lines show before the text is cut; -1 for no limit.
    public static let maximumLines = ElementProperty<Self, Int>(
        "maximumLines", layer: .native, travels: false)

    /// The element's own members.
    public static let members: [any ContractMember] = [lineBreak, maximumLines]
}
