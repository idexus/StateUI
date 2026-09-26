// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// What an element showing words takes of the text tiers, read the same on every host: the words in their case,
/// and the look its font and colour give them.
/// Design: docs/design/host/tree.md#runs-of-words
@_spi(Host) public enum TextMembers {
    /// What every element showing words takes: the words in their case, the font, their colour, and the room
    /// around them.
    public static let members: [any ContractMember] = [
        TextElementContract.text, TextElementContract.textCase, FontElementContract.fontSize,
        FontElementContract.fontAttributes, FontElementContract.fontFamily, TextStyleElementContract.textColor,
        PaddingElementContract.padding,
    ]

    /// The words in their case, where the words or their case changed; nil where neither did.
    public static func words<Realized>(_ values: ElementValues<Realized>) -> String? {
        guard values.changed(TextElementContract.text) || values.changed(TextElementContract.textCase) else {
            return nil
        }
        let text = values[TextElementContract.text] ?? ""
        return values[TextElementContract.textCase]?.applied(to: text) ?? text
    }

    /// The look the font and the colour give the words, where one of them changed; nil where none did.
    public static func look<Realized>(_ values: ElementValues<Realized>) -> TextLook? {
        guard values.changed(FontElementContract.fontSize) || values.changed(FontElementContract.fontAttributes)
            || values.changed(FontElementContract.fontFamily) || values.changed(TextStyleElementContract.textColor)
        else { return nil }
        var look = TextLook()
        look.size = values[FontElementContract.fontSize]
        look.attributes = values[FontElementContract.fontAttributes] ?? .none
        look.family = values[FontElementContract.fontFamily]?.text
        look.color = values[TextStyleElementContract.textColor]?.propValue
        return look
    }
}
