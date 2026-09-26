// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

struct AppKitBrush {
    enum Kind {
        case none
        case solid(NSColor)
        case linear([NSColor], [CGFloat], [Double])
        case radial([NSColor], [CGFloat], [Double])
    }

    var kind = Kind.none

    init() {}

    init(color: NSColor?) {
        kind = color.map(Kind.solid) ?? .none
    }

    init?(_ value: HostValue?) {
        guard let parts = value?.values, let rawKind = parts.first?.enumeration else { return nil }

        if rawKind == 1, let color = parts.value(1).flatMap(nsColor) {
            kind = .solid(color)
            return
        }

        guard rawKind == 2 || rawKind == 3,
              let geometry = parts.value(1)?.numbers
        else { return nil }

        var colors: [NSColor] = []
        var locations: [CGFloat] = []
        var index = 2

        while index + 1 < parts.count,
              let location = parts[index].number,
              let color = nsColor(parts[index + 1]) {
            locations.append(min(max(location, 0), 1))
            colors.append(color)
            index += 2
        }

        guard !colors.isEmpty else { return nil }
        kind = rawKind == 2
            ? .linear(colors, locations, geometry)
            : .radial(colors, locations, geometry)
    }

    func draw(in path: NSBezierPath, bounds: NSRect) {
        switch kind {
        case .none:
            return
        case .solid(let color):
            color.setFill()
            path.fill()
        case .linear(let colors, let locations, let geometry):
            guard geometry.count >= 4,
                  let gradient = NSGradient(
                    colors: colors,
                    atLocations: locations,
                    colorSpace: .deviceRGB)
            else { return }
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            gradient.draw(
                from: NSPoint(
                    x: bounds.minX + bounds.width * geometry[0],
                    y: bounds.minY + bounds.height * geometry[1]),
                to: NSPoint(
                    x: bounds.minX + bounds.width * geometry[2],
                    y: bounds.minY + bounds.height * geometry[3]),
                options: [])
            NSGraphicsContext.restoreGraphicsState()
        case .radial(let colors, let locations, let geometry):
            guard geometry.count >= 3,
                  let gradient = NSGradient(
                    colors: colors,
                    atLocations: locations,
                    colorSpace: .deviceRGB)
            else { return }
            NSGraphicsContext.saveGraphicsState()
            path.addClip()
            let center = NSPoint(
                x: bounds.minX + bounds.width * geometry[0],
                y: bounds.minY + bounds.height * geometry[1])
            gradient.draw(
                fromCenter: center,
                radius: 0,
                toCenter: center,
                radius: max(bounds.width, bounds.height) * geometry[2],
                options: [])
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    func stroke(_ path: NSBezierPath, width: CGFloat) {
        guard case .solid(let color) = kind else { return }
        color.setStroke()
        path.lineWidth = width
        path.stroke()
    }
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
