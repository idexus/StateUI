// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import StateUIFoundation

/// What a host that blurs nothing showed, read back as the material it stands for: the blur whose color of the
/// theme in force it painted, else the color itself.
@_spi(Host) public enum StandIns {
    /// The material a view painting `painted` shows: a blur, where `painted` is the color a host that blurs nothing
    /// draws for one, else the color.
    @MainActor public static func material(painted: Color) -> Material {
        let drawn = painted.propValue
        let blur = Blur.Thickness.allCases.first { HostMaterial(Material.blur(Blur($0)).propValue).standIn == drawn }
        return blur.map { .blur(Blur($0)) } ?? .color(painted)
    }

    /// The material a view painting `painted` shows: its color as `material(painted:)` reads one, or the gradient
    /// itself; nil for nothing, or a color that is none.
    @MainActor public static func material(painted: HostBrush) -> Material? {
        func stops(_ stops: [HostBrush.Stop]) -> [GradientStop]? {
            let read = stops.compactMap { stop in Color(propValue: stop.color).map { GradientStop($0, stop.offset) } }
            return read.count == stops.count ? read : nil
        }
        switch painted {
        case .none: return nil
        case .solid(let color): return Color(propValue: color).map { material(painted: $0) }
        case .linear(let from, let to, let run):
            return stops(run).map { .gradient(.linearGradient($0, startPoint: from, endPoint: to)) }
        case .radial(let center, let radius, let run):
            return stops(run).map { .gradient(.radialGradient($0, center: center, radius: radius)) }
        }
    }

    /// A line's gradient as CSS paints a box `width` by `height` - its angle, nil for CSS's own straight down, then
    /// each stop's color at its place on CSS's line - read back to its points in fractions of the box
    /// (`CSSGradientLine` turned around), from its first stop's place to its last's, each a millionth at most from
    /// where it stood; nil for fewer than two stops, or the last at or before the first.
    public static func material(
        cssAngle: Double?, stops: [(color: Color, place: Double)], width: Double, height: Double
    ) -> Material? {
        guard stops.count > 1, let first = stops.first?.place, let last = stops.last?.place, last > first else {
            return nil
        }
        let radians = (cssAngle ?? 180) * Double.pi / 180
        let (ux, uy) = (sin(radians), -cos(radians))
        let line = abs(width * ux) + abs(height * uy)
        func nearest(_ value: Double) -> Double { (value * 1e6).rounded() / 1e6 }
        func point(_ place: Double) -> Point {
            Point(
                x: nearest((width / 2 + (place - 0.5) * line * ux) / width),
                y: nearest((height / 2 + (place - 0.5) * line * uy) / height))
        }
        return .gradient(.linearGradient(
            stops.map { GradientStop($0.color, nearest(($0.place - first) / (last - first))) },
            startPoint: point(first), endPoint: point(last)))
    }
}
