// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The font text is drawn in: its family, its size, its weight and slant, and
/// whether it follows the reader's text-size setting.
public enum FontElementContract: Contract {
    /// The tier's name.
    public static let name = "FontElement"

    /// A font is carried as values in the tree.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self]

    /// Whether the text is bold, italic, or both.
    public static let fontAttributes = ElementProperty<Self, FontAttributes>("fontAttributes", layer: .native)

    /// Whether the text follows the reader's text-size setting.
    public static let fontAutoScalingEnabled = ElementProperty<Self, Bool>(
        "fontAutoScalingEnabled", layer: .adaptive)

    /// The font family, by its name.
    public static let fontFamily = ElementProperty<Self, Name>("fontFamily", layer: .native)

    /// The font size, in device units.
    public static let fontSize = ElementProperty<Self, Double>("fontSize", layer: .native, moves: .text)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        fontAttributes, fontAutoScalingEnabled, fontFamily, fontSize,
    ]
}
