// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A brush as CSS paints a box `size` across: a color, or a gradient whose points are fractions of the box and
/// whose stripes stand square to it in pixels - a radial one a circle as far as the host layer's reach.
/// Design: docs/design/platforms/web/drawing.md#a-brush-on-a-box
enum WebBrush {
    /// The brush as a CSS image, a color as one too, so it can stand in a layer of a background; nil for none.
    static func image(_ value: HostValue?, size: LayoutSize) -> String? {
        switch HostBrush(value) {
        case .none:
            return nil
        case .solid(let color):
            return WebCSS.color(color).map { "linear-gradient(\($0), \($0))" }
        case .linear(let from, let to, let stops):
            let line = CSSGradientLine(from: from, to: to, stops: stops, width: size.width, height: size.height)
            return "linear-gradient(" + (line.angle.map { WebCSS.number($0) + "deg, " } ?? "")
                + written(zip(stops, line.places).map { ($0.color, $1) }) + ")"
        case .radial(let center, let radius, let stops):
            let reach = HostBrush.reach(of: radius, width: size.width, height: size.height)
            let n: (Double) -> String = WebCSS.number
            return "radial-gradient(circle \(n(max(reach, 0.0001)))px at \(n(center.x * size.width))px "
                + "\(n(center.y * size.height))px, " + written(stops.map { ($0.color, $0.offset) }) + ")"
        }
    }

    /// The stops as CSS writes them, each a color at its place on the line.
    private static func written(_ stops: [(color: HostValue, place: Double)]) -> String {
        stops.map { stop in
            (WebCSS.color(stop.color) ?? "transparent") + " " + WebCSS.number(stop.place * 100) + "%"
        }.joined(separator: ", ")
    }
}
