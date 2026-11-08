// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What every element drawing its words itself has: the case they are drawn
/// in, their color, and the words.
public enum TextualElementContract: Tier {
    /// The tier's name.
    public static let name = "TextualElement"

    /// Its words, drawn in a color.
    public static let tiers: [any Tier.Type] = [TextColorElementContract.self, TextElementContract.self]

    /// Whether the words are drawn as written or in one case throughout.
    public static let textCase = ElementProperty<Self, TextCase>("textCase", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [textCase]
}
