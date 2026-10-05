// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import WASILibc

/// A brush as CSS paints a box `size` across: a colour, or a gradient whose points are fractions of the box and
/// whose stripes stand square to it in pixels - a radial one a circle as far as the host layer's reach.
/// Design: docs/design/platforms/web/drawing.md#a-brush-on-a-box
enum WebBrush {
    /// The brush as a CSS image, a colour as one too, so it can stand in a layer of a background; nil for none.
    static func image(_ value: HostValue?, size: LayoutSize) -> String? {
        switch HostBrush(value) {
        case .none:
            return nil
        case .solid(let color):
            return WebCSS.color(color).map { "linear-gradient(\($0), \($0))" }
        case .linear(let from, let to, let stops):
            return linear(from: from, to: to, stops: stops, size: size)
        case .radial(let center, let radius, let stops):
            let reach = HostBrush.reach(of: radius, width: size.width, height: size.height)
            let n: (Double) -> String = WebCSS.number
            return "radial-gradient(circle \(n(max(reach, 0.0001)))px at \(n(center.x * size.width))px "
                + "\(n(center.y * size.height))px, " + written(stops) { $0 } + ")"
        }
    }

    /// Whether the brush is a gradient, which follows the size of the box it paints.
    static func isGradient(_ value: HostValue?) -> Bool {
        switch HostBrush(value) {
        case .linear, .radial: true
        default: false
        }
    }

    /// A gradient from one point to another as CSS's: its angle, and each stop where it stands on CSS's own line,
    /// which runs through the box's middle as long as the box is across that angle.
    private static func linear(from: Point, to: Point, stops: [HostBrush.Stop], size: LayoutSize) -> String {
        let (startX, startY) = (from.x * size.width, from.y * size.height)
        let (dx, dy) = (to.x * size.width - startX, to.y * size.height - startY)
        let length = (dx * dx + dy * dy).squareRoot()
        guard length > 0 else { return "linear-gradient(" + written(stops) { $0 } + ")" }
        let (ux, uy) = (dx / length, dy / length)
        let line = abs(size.width * ux) + abs(size.height * uy)
        let angle = atan2(dx, -dy) * 180 / Double.pi
        let (middleX, middleY) = (size.width / 2, size.height / 2)
        return "linear-gradient(\(WebCSS.number(angle))deg, " + written(stops) { offset in
            let x = startX + offset * dx - middleX
            let y = startY + offset * dy - middleY
            return line > 0 ? (x * ux + y * uy) / line + 0.5 : offset
        } + ")"
    }

    /// The stops as CSS writes them, each at `place(offset)` of the line.
    private static func written(_ stops: [HostBrush.Stop], at place: (Double) -> Double) -> String {
        stops.map { stop in
            (WebCSS.color(stop.color) ?? "transparent") + " " + WebCSS.number(place(stop.offset) * 100) + "%"
        }.joined(separator: ", ")
    }
}
