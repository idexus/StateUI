// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A box a view paints of its own - a layout's, a button's: what fills it, its outline inside its edge, and its
/// shape - as CSS: a colour or a gradient behind it, a border, and its corners. An outline of a gradient is a
/// border the box's background shows through, its two layers cut to the box and to its inside.
/// Design: docs/design/platforms/web/drawing.md#a-brush-on-a-box
struct WebBox: Equatable {
    var fill: HostValue?
    var stroke: HostValue?
    var lineWidth: Double?
    var shape: HostValue?

    /// The border a box drawn with no outline stands with: nil for none of its own, "none" to lose the page's.
    var borderless: String?

    /// Whether the box says anything of its own.
    var isDrawn: Bool { fill != nil || stroke != nil || shape != nil }

    /// Whether the box paints a gradient, which follows its size.
    var followsSize: Bool { WebBrush.isGradient(fill) || WebBrush.isGradient(stroke) }

    /// The box's CSS for a box `size` across.
    func styles(size: LayoutSize) -> [(String, String?)] {
        let width = BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth)
        // A shape the tree states wins over the look's corners - square ones too; one unsaid leaves them.
        let corners = ("border-radius", shape == nil ? nil : WebCSS.corners(BoxArithmetic.outline(shape)) ?? "0")
        guard WebBrush.isGradient(stroke), width > 0 else {
            let border = width > 0
                ? "\(WebCSS.pixels(width)!) solid \(WebCSS.color(HostBrush(stroke).firstColor) ?? "currentColor")"
                : isDrawn ? borderless : nil
            let behind = WebBrush.isGradient(fill) ? WebBrush.image(fill, size: size) : WebCSS.fill(fill)
            return [("background", behind), ("border", border), corners]
        }
        let inside = WebBrush.image(fill, size: size) ?? "linear-gradient(transparent, transparent)"
        let outline = WebBrush.image(stroke, size: size) ?? "none"
        return [("background", "\(inside) padding-box, \(outline) border-box"),
                ("border", "\(WebCSS.pixels(width)!) solid transparent"), corners]
    }
}
