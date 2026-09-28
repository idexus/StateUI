// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How text looks wherever it is drawn: its colour and the space between its
/// letters.
public enum TextStyleElementContract: Contract {
    /// The tier's name.
    public static let name = "TextStyleElement"

    /// Text carries values in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// The space between the letters.
    public static let characterSpacing = ElementProperty<Self, Double>(
        "characterSpacing", layer: .native, moves: .text)

    /// The colour the text is drawn in.
    public static let textColor = ElementProperty<Self, Color>("textColor", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [characterSpacing, textColor]
}
