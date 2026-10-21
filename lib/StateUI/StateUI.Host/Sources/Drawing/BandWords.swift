// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Words on a band the tree paints - a bar, a row of tabs - the same on every host: light on a dark band, dark on a
/// light one, where the tree writes no color for them.
/// Design: docs/design/host/layout.md#words-on-a-painted-band
@_spi(Host) public enum BandWords {
    /// Whether words on `band` are drawn light: its relative luminance, Rec. 709, below a half. Nil for a value that
    /// is no color.
    public static func light(on band: HostValue) -> Bool? {
        guard let color = band.fractions else { return nil }
        return 0.2126 * color.red + 0.7152 * color.green + 0.0722 * color.blue < 0.5
    }

    /// The color of words on `band`: the one the tree writes, `written`, else white on a dark band and black on a
    /// light one; nil where nothing is written and the band is no color.
    public static func color(on band: HostValue?, written: HostValue?) -> HostValue? {
        if let written { return written }
        guard let light = band.flatMap(light(on:)) else { return nil }
        let shade: UInt8 = light ? 255 : 0
        return .color(red: shade, green: shade, blue: shade, alpha: 255)
    }
}
