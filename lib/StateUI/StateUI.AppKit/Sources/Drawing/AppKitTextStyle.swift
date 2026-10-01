// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The native font a caption is drawn in: the family where one is named, at
/// the size given or the fallback's, bold and italic where the attributes say
/// so. The host composes it from an element's values and a registration from
/// the members it reads - one composition, either way.
@MainActor
func appKitFont(family: String?, size: Double?, attributes: FontAttributes?, fallback: NSFont) -> NSFont {
    let points = size ?? fallback.pointSize
    let traits = attributes ?? .none
    var font = family.flatMap { NSFont(name: $0, size: points) } ?? NSFont.systemFont(ofSize: points)
    if traits.contains(.bold) { font = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) }
    if traits.contains(.italic) { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
    return font
}

/// Words' attributes from how the host layer says they look (`TextLook`), drawn in `font`: their colour, else
/// `fallbackColor`, what stands behind them, the space between the letters, the lines' height and decorations.
/// Design: docs/design/host/tree.md#runs-of-words
@MainActor
func appKitAttributes(_ look: TextLook, font: NSFont, fallbackColor: NSColor) -> [NSAttributedString.Key: Any] {
    var attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: look.color.flatMap(nsColor) ?? fallbackColor,
        .kern: look.letterSpacing,
    ]
    if let background = look.background.flatMap(nsColor) { attributes[.backgroundColor] = background }
    if look.decorations.contains(.underline) { attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue }
    if look.decorations.contains(.strikethrough) {
        attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
    }
    if let lineHeight = look.lineHeight, lineHeight.isFinite, lineHeight > 0 {
        let paragraph = NSMutableParagraphStyle()
        let height = font.boundingRectForFont.height * lineHeight
        paragraph.minimumLineHeight = height
        paragraph.maximumLineHeight = height
        attributes[.paragraphStyle] = paragraph
    }
    return attributes
}

/// Where text sits across its element, as AppKit draws it.
func appKitTextAlignment(_ value: Int32?) -> NSTextAlignment {
    switch value {
    case 1: return .center
    case 2: return .right
    default: return .left
    }
}

#endif
