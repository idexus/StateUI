// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// Words on a band the tree paints - a bar, a row of tabs - the same on every host: light on a dark band, dark on a
/// light one, where the tree writes no color for them.
/// Design: docs/design/host/layout.md#words-on-a-painted-band
@_spi(Host) public enum BandWords {
    /// Whether words on `band` are drawn light: its relative luminance, Rec. 709, below a half - a gradient's the
    /// mean of its stops'. Nil for a value that is neither a color nor a gradient.
    public static func light(on band: HostValue) -> Bool? {
        let colors: [HostValue] = switch HostBrush(band) {
        case .none: []
        case .solid(let color): [color]
        case .linear(_, _, let stops), .radial(_, _, let stops): stops.map(\.color)
        }
        let luminances = colors.compactMap(\.fractions).map { 0.2126 * $0.red + 0.7152 * $0.green + 0.0722 * $0.blue }
        guard !luminances.isEmpty else { return nil }
        return luminances.reduce(0, +) / Double(luminances.count) < 0.5
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
