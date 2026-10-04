// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where text sits inside the space its own element was given.
public enum TextAlignmentElementContract: Contract {
    /// The tier's name.
    public static let name = "TextAlignmentElement"

    /// Aligned text is drawn.
    public static let tiers: [any Contract.Type] = [VisualElementContract.self]

    /// Where the text sits across its element.
    public static let horizontalTextAlignment = ElementProperty<Self, TextAlignment>(
        "horizontalTextAlignment", layer: .native)

    /// Where the text sits down its element.
    public static let verticalTextAlignment = ElementProperty<Self, TextAlignment>(
        "verticalTextAlignment", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [horizontalTextAlignment, verticalTextAlignment]
}
