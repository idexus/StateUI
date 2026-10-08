// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A fill drawn by AppKit: the host layer's reading of it (`HostBrush`), its colours in sRGB, painted on a path.
/// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
struct AppKitBrush {
    /// What the tree's value describes.
    let brush: HostBrush

    /// The brush the tree's `value` describes: a colour, a gradient, or nothing.
    init(_ value: HostValue? = nil) {
        brush = HostBrush(value)
    }

    /// Its one colour, where it is one.
    var color: NSColor? {
        if case .solid(let color) = brush { nsColor(color) } else { nil }
    }

    /// Whether it paints anything.
    var paints: Bool {
        brush != .none
    }

    /// Whether it is a gradient, which a layer's colour cannot paint.
    var isGradient: Bool {
        switch brush {
        case .linear, .radial: true
        case .none, .solid: false
        }
    }

    /// The colour a line draws with: its colour, or its first stop's.
    var lineColor: NSColor? {
        brush.firstColor.flatMap(nsColor)
    }

    /// Fills `path` within `bounds`: a gradient's points and radius are fractions of `bounds`, the radius of its
    /// larger side.
    func draw(in path: NSBezierPath, bounds: NSRect) {
        switch brush {
        case .none:
            return
        case .solid(let value):
            nsColor(value)?.setFill()
            path.fill()
        case .linear(let from, let to, let stops):
            guard let gradient = Self.gradient(stops) else { return }
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            gradient.draw(from: Self.point(from, in: bounds), to: Self.point(to, in: bounds), options: [])
            NSGraphicsContext.restoreGraphicsState()
        case .radial(let center, let radius, let stops):
            guard let gradient = Self.gradient(stops) else { return }
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let middle = Self.point(center, in: bounds)
            gradient.draw(
                fromCenter: middle, radius: 0, toCenter: middle,
                radius: HostBrush.reach(of: radius, width: bounds.width, height: bounds.height),
                options: [])
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// Strokes `path` `width` wide in the brush's line colour.
    func stroke(_ path: NSBezierPath, width: CGFloat) {
        guard let color = lineColor, width > 0 else { return }
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }

    private static func gradient(_ stops: [HostBrush.Stop]) -> NSGradient? {
        let colors = stops.compactMap { nsColor($0.color) }
        guard !colors.isEmpty, colors.count == stops.count else { return nil }
        return NSGradient(colors: colors, atLocations: stops.map { CGFloat($0.offset) }, colorSpace: .deviceRGB)
    }

    private static func point(_ fraction: Point, in bounds: NSRect) -> NSPoint {
        NSPoint(x: bounds.minX + bounds.width * fraction.x, y: bounds.minY + bounds.height * fraction.y)
    }
}

/// The colour a view that blurs nothing paints its background in: a colour, or a blur's or glass's tint over the
/// colour standing in for it (`HostMaterial.painted`); nil for a gradient or nothing.
@MainActor
func paintedColor(_ material: HostValue?) -> NSColor? {
    HostMaterial(material).painted.flatMap(nsColor)
}

/// A StateUI colour is four sRGB channels, drawn in sRGB exactly.
func nsColor(_ value: HostValue) -> NSColor? {
    guard let color = value.color else { return nil }
    return NSColor(
        srgbRed: CGFloat(color.red) / 255,
        green: CGFloat(color.green) / 255,
        blue: CGFloat(color.blue) / 255,
        alpha: CGFloat(color.alpha) / 255)
}

#endif
