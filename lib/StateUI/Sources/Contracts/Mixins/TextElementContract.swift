// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every element showing words has: the words, and the case they are
/// drawn in.
public enum TextElementContract: Contract {
    /// The tier's name.
    public static let name = "TextElement"

    /// Words are drawn in a colour and a spacing.
    public static let tiers: [any Contract.Type] = [TextStyleElementContract.self]

    /// The words.
    public static let text = ElementProperty<Self, String>("text", layer: .native)

    /// Whether the words are drawn as written or in one case throughout.
    public static let textCase = ElementProperty<Self, TextCase>("textCase", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [text, textCase]
}
