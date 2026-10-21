// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What an element showing words takes of the text tiers, read the same on every host: the words in their case,
/// and the look its font and color give them.
/// Design: docs/design/host/tree.md#runs-of-words
@_spi(Host) public enum TextMembers {
    /// What every element showing words takes: the words in their case, their look, and the room around them.
    public static let members = PropertyList(TextualElementContract.text, TextualElementContract.textCase)
        + lookMembers + PropertyList(PaddingElementContract.padding)

    /// What a toggle takes for the words beside it - a check box's, a switch's: the words in their case and their
    /// color, in the platform's own font.
    public static let captionMembers = PropertyList(
        TextualElementContract.text, TextualElementContract.textCase, TextColorElementContract.textColor)

    /// What the words' look is made of, which `look` reads: the font, whether it follows the user's text size, and
    /// the words' color.
    public static let lookMembers = fontMembers
        + PropertyList(FontElementContract.isFontAutoScalingEnabled, TextColorElementContract.textColor)

    /// What the words' font is made of: its style, size, weight, slant and family.
    public static let fontMembers = PropertyList(
        FontElementContract.textStyle, FontElementContract.fontSize, FontElementContract.fontWeight,
        FontElementContract.fontAttributes, FontElementContract.fontFamily)

    /// A toggle's words beside it in their case, whether or not they changed; empty where it says none.
    public static func caption<Realized>(_ values: ElementValues<Realized>) -> String {
        let text = values[TextualElementContract.text] ?? ""
        return values[TextualElementContract.textCase]?.applied(to: text) ?? text
    }

    /// A toggle's words' look: their color, in the platform's own font.
    public static func captionLook<Realized>(_ values: ElementValues<Realized>) -> TextLook {
        var look = TextLook()
        look.color = values[TextColorElementContract.textColor]?.propValue
        return look
    }

    /// The words in their case, where the words or their case changed; nil where neither did.
    public static func words<Realized>(_ values: ElementValues<Realized>) -> String? {
        guard values.changed(TextualElementContract.text) || values.changed(TextualElementContract.textCase) else {
            return nil
        }
        let text = values[TextualElementContract.text] ?? ""
        return values[TextualElementContract.textCase]?.applied(to: text) ?? text
    }

    /// The look the font, its scaling and the color give the words, where one of them changed; nil where none did.
    public static func look<Realized>(_ values: ElementValues<Realized>) -> TextLook? {
        guard values.changed(FontElementContract.textStyle) || values.changed(FontElementContract.fontWeight)
            || values.changed(FontElementContract.fontSize) || values.changed(FontElementContract.fontAttributes)
            || values.changed(FontElementContract.fontFamily) || values.changed(TextColorElementContract.textColor)
            || values.changed(FontElementContract.isFontAutoScalingEnabled)
        else { return nil }
        return look(of: values)
    }

    /// The look the font and the color give the words, whether or not they changed.
    public static func look<Realized>(of values: ElementValues<Realized>) -> TextLook {
        var look = TextLook()
        look.style = values[FontElementContract.textStyle]
        look.size = values[FontElementContract.fontSize]
        look.weight = values[FontElementContract.fontWeight]
        look.attributes = values[FontElementContract.fontAttributes] ?? .none
        look.attributesGiven = values[FontElementContract.fontAttributes] != nil
        look.family = values[FontElementContract.fontFamily]?.text
        look.color = values[TextColorElementContract.textColor]?.propValue
        look.scales = values[FontElementContract.isFontAutoScalingEnabled] ?? true
        return look
    }
}
