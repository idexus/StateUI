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
func appKitFont(family: String?, size: Double?, attributes: Int32?, fallback: NSFont) -> NSFont {
    let points = size ?? fallback.pointSize
    let traits = attributes ?? 0
    var font = family.flatMap { NSFont(name: $0, size: points) } ?? NSFont.systemFont(ofSize: points)

    if traits & 1 == 1, let bold = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask) as NSFont? {
        font = bold
    }

    if traits & 2 == 2, let italic = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask) as NSFont? {
        font = italic
    }

    return font
}

/// Where text sits across its element, as AppKit draws it.
func appKitTextAlignment(_ value: Int32?) -> NSTextAlignment {
    switch value {
    case 1: return .center
    case 2: return .right
    default: return .left
    }
}

/// Words drawn as written, or in the one case the tree asks for.
func appKitTextCased(_ text: String, _ transform: Int32?) -> String {
    switch transform {
    case 2: return text.lowercased()
    case 3: return text.uppercased()
    default: return text
    }
}

#endif
