// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUIHost

/// A picture as a tab or a menu's entry shows it: a glyph beside words in the system font.
extension NSImage {
    /// How tall a glyph stands beside words in the system font.
    static let glyphHeight = (NSFont.systemFontSize * 1.25).rounded()

    /// The picture `glyphHeight` tall and as wide as its shape makes it (`PictureArithmetic.glyph`) - its own
    /// pixels, drawn smaller - a template the system tints where `tinted`; the picture itself is left as it is.
    @MainActor
    func glyph(tinted: Bool) -> NSImage {
        guard let copy = copy() as? NSImage else { return self }
        if tinted { copy.isTemplate = true }
        let fitted = PictureArithmetic.glyph(LayoutSize(width: size.width, height: size.height), height: Self.glyphHeight)
        copy.size = NSSize(width: fitted.width, height: fitted.height)
        Self.sources.setObject(self, forKey: copy)
        return copy
    }

    /// The picture a glyph was drawn from; nil for a picture that is no glyph.
    @MainActor
    var glyphSource: NSImage? {
        Self.sources.object(forKey: self)
    }

    /// Each glyph's picture, held by neither.
    @MainActor
    private static let sources = NSMapTable<NSImage, NSImage>.weakToWeakObjects()
}
#endif
