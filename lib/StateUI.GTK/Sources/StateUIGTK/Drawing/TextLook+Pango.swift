// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A look as the Pango attributes GTK draws words with.
/// Design: docs/design/platforms/gtk/controls.md#words
extension TextLook {
    /// The words' colour as GTK draws it; nil for GTK's own.
    var rgbaColor: GdkRGBA? { color.flatMap(GTKBrush.rgba) }

    /// What stands behind the words as GTK draws it: a brush's first colour; nil for nothing.
    var rgbaBackground: GdkRGBA? { GTKBrush(background).firstColor }

    /// Puts the look on the words from byte `start` to byte `end` of `list`.
    func insert(into list: OpaquePointer, from start: UInt32 = 0, to end: UInt32 = UInt32.max) {
        var made: [UnsafeMutablePointer<PangoAttribute>] = []
        if let size, size > 0 { made.append(pango_attr_size_new_absolute(Int32((size * Double(PANGO_SCALE)).rounded()))) }
        if attributes.contains(.bold) { made.append(pango_attr_weight_new(PANGO_WEIGHT_BOLD)) }
        if attributes.contains(.italic) { made.append(pango_attr_style_new(PANGO_STYLE_ITALIC)) }
        if let family, !family.isEmpty { made.append(pango_attr_family_new(family)) }
        if let color = rgbaColor {
            let (red, green, blue, alpha) = Self.channels(color)
            made += [pango_attr_foreground_new(red, green, blue), pango_attr_foreground_alpha_new(alpha)]
        }
        if let background = rgbaBackground {
            let (red, green, blue, alpha) = Self.channels(background)
            made += [pango_attr_background_new(red, green, blue), pango_attr_background_alpha_new(alpha)]
        }
        if letterSpacing != 0 {
            made.append(pango_attr_letter_spacing_new(Int32((letterSpacing * Double(PANGO_SCALE)).rounded())))
        }
        if let lineHeight, lineHeight > 0 { made.append(pango_attr_line_height_new(lineHeight)) }
        if decorations.contains(.underline) { made.append(pango_attr_underline_new(PANGO_UNDERLINE_SINGLE)) }
        if decorations.contains(.strikethrough) { made.append(pango_attr_strikethrough_new(1)) }

        for attribute in made {
            attribute.pointee.start_index = start
            attribute.pointee.end_index = end
            pango_attr_list_insert(list, attribute)
        }
    }

    /// A colour's channels as Pango takes them, each 0 to 65535.
    private static func channels(_ color: GdkRGBA) -> (UInt16, UInt16, UInt16, UInt16) {
        func channel(_ value: Float) -> UInt16 { UInt16((min(max(value, 0), 1) * 65535).rounded()) }
        return (channel(color.red), channel(color.green), channel(color.blue), channel(color.alpha))
    }
}
