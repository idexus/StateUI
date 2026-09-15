// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The lines drawn through or under text.
public enum DecorableTextElementContract: Contract {
    /// The tier's name.
    public static let name = "DecorableTextElement"

    /// Decorations are carried as a value in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// Whether the text is underlined, struck through, or both.
    public static let textDecorations = ElementProperty<Self, TextDecorations>("textDecorations", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [textDecorations]
}
