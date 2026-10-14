// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The font text is drawn in: its step of the platform's type ramp, its family,
/// its size, its weight and slant, and whether it follows the user's text-size
/// setting.
public enum FontElementContract: Contract {
    /// The tier's name.
    public static let name = "FontElement"

    /// Whether the text is italic.
    public static let fontAttributes = ElementProperty<Self, FontAttributes>("fontAttributes", layer: .native)

    /// How heavy the text's strokes are, over its style's weight.
    public static let fontWeight = ElementProperty<Self, FontWeight>("fontWeight", layer: .native)

    /// The step of the platform's type ramp the text is set in: its size and weight, under any the text gives itself.
    public static let textStyle = ElementProperty<Self, TextStyle>("textStyle", layer: .native)

    /// Whether the text follows the user's text-size setting.
    public static let isFontAutoScalingEnabled = ElementProperty<Self, Bool>(
        "isFontAutoScalingEnabled", layer: .adaptive)

    /// The font family, by its name.
    public static let fontFamily = ElementProperty<Self, Name>("fontFamily", layer: .native)

    /// The font size, in device units.
    public static let fontSize = ElementProperty<Self, Double>("fontSize", layer: .native, moves: .text)

    /// The tier's own members.
    public static let members: [any ContractMember] = [
        fontAttributes, fontWeight, textStyle, isFontAutoScalingEnabled, fontFamily, fontSize,
    ]
}
