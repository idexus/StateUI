// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The native font words are drawn in, as they look (`TextLook`): their style's font from AppKit's type ramp, else
/// `fallback`; the size and weight the tree gives over the style's; the family where one is named, and italic where
/// the slant says so. The host composes it from an element's values and a registration from the members it reads -
/// one composition, either way.
/// Design: docs/design/platforms/appkit/views.md#a-text-style
@MainActor
func appKitFont(_ look: TextLook, fallback: NSFont) -> NSFont {
    let styled = look.style.map { NSFont.preferredFont(forTextStyle: $0.appKit) }
    let (size, weight) = look.standing(
        styleSize: styled.map { Double($0.pointSize) }, styleWeight: styled.map { FontWeight(appKit: $0.weight) })
    let points = size.map { CGFloat($0) } ?? fallback.pointSize
    let thickness = weight?.appKit ?? fallback.weight
    var font = look.family.flatMap { family in
        NSFont(descriptor: NSFontDescriptor(fontAttributes: [
            .family: family, .traits: [NSFontDescriptor.TraitKey.weight: thickness],
        ]), size: points)
    } ?? NSFont.systemFont(ofSize: points, weight: thickness)
    if look.attributes.contains(.italic) { font = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) }
    return font
}

extension TextStyle {
    /// AppKit's step of its type ramp for the style.
    var appKit: NSFont.TextStyle {
        switch self {
        case .display: .largeTitle
        case .title: .title1
        case .subtitle: .title2
        case .headline: .headline
        case .body: .body
        case .caption: .caption1
        }
    }
}

extension FontWeight {
    /// AppKit's weight for it.
    var appKit: NSFont.Weight {
        switch self {
        case .regular: .regular
        case .medium: .medium
        case .semibold: .semibold
        case .bold: .bold
        }
    }

    /// The weight nearest AppKit's `weight`.
    init(appKit weight: NSFont.Weight) {
        let steps = FontWeight.allCases.map { abs($0.appKit.rawValue - weight.rawValue) }
        self = FontWeight.allCases[steps.firstIndex(of: steps.min() ?? 0) ?? 0]
    }
}

extension NSFont {
    /// How heavy the font's strokes are, as its descriptor says; regular where it says nothing.
    var weight: NSFont.Weight {
        let traits = fontDescriptor.object(forKey: .traits) as? [NSFontDescriptor.TraitKey: Any]
        return NSFont.Weight((traits?[.weight] as? CGFloat) ?? 0)
    }
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
