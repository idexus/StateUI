// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// StateUI's drawing as SVG writes it: a path's commands, a rounded rectangle, an ellipse, an affine matrix, and a
/// gradient's geometry over the room it paints.
/// Design: docs/design/platforms/web/drawing.md#a-shape
enum WebVector {
    /// The host layer's flat commands - move, line, cubic, quadratic, close, each with its points - as SVG's.
    static func path(_ commands: [Double]) -> String {
        var written: [String] = []
        var index = 0
        while index < commands.count {
            let op = Int(commands[index])
            index += 1
            let need = op == 0 || op == 1 ? 2 : op == 2 ? 6 : op == 3 ? 4 : 0
            guard index + need <= commands.count else { break }
            let points = commands[index..<index + need].map(WebCSS.number).joined(separator: " ")
            index += need
            switch op {
            case 0: written.append("M " + points)
            case 1: written.append("L " + points)
            case 2: written.append("C " + points)
            case 3: written.append("Q " + points)
            case 4: written.append("Z")
            default: break
            }
        }
        return written.joined(separator: " ")
    }

    /// A rectangle in `room` with its corners rounded - top left, top right, bottom right, bottom left - each fitted
    /// into the room as the host layer fits a box's corners.
    static func rounded(_ room: Rect, radii: [Double]) -> String {
        let corners = (0..<4).map { index in
            let radius = index < radii.count && radii[index].isFinite ? max(0, radii[index]) : 0
            return BoxArithmetic.fitted(radius, width: room.width, height: room.height)
        }
        let (x, y, right, bottom) = (room.x, room.y, room.x + room.width, room.y + room.height)
        let n: (Double) -> String = WebCSS.number
        func arc(_ corner: (width: Double, height: Double), _ toX: Double, _ toY: Double) -> String {
            "A \(n(corner.width)) \(n(corner.height)) 0 0 1 \(n(toX)) \(n(toY))"
        }
        return ["M \(n(x + corners[0].width)) \(n(y))", "L \(n(right - corners[1].width)) \(n(y))",
                arc(corners[1], right, y + corners[1].height), "L \(n(right)) \(n(bottom - corners[2].height))",
                arc(corners[2], right - corners[2].width, bottom), "L \(n(x + corners[3].width)) \(n(bottom))",
                arc(corners[3], x, bottom - corners[3].height), "L \(n(x)) \(n(y + corners[0].height))",
                arc(corners[0], x + corners[0].width, y), "Z"].joined(separator: " ")
    }

    /// The ellipse filling `room`.
    static func ellipse(in room: Rect) -> String {
        let n: (Double) -> String = WebCSS.number
        let (rx, ry) = (room.width / 2, room.height / 2)
        let (cx, cy) = (room.x + rx, room.y + ry)
        return "M \(n(cx - rx)) \(n(cy)) A \(n(rx)) \(n(ry)) 0 1 0 \(n(cx + rx)) \(n(cy)) "
            + "A \(n(rx)) \(n(ry)) 0 1 0 \(n(cx - rx)) \(n(cy)) Z"
    }

    /// An affine transform's six numbers as SVG's `matrix`; nil for numbers that are not six and finite.
    static func matrix(_ numbers: [Double]) -> String? {
        guard numbers.count == 6, numbers.allSatisfy(\.isFinite) else { return nil }
        return "matrix(" + numbers.map(WebCSS.number).joined(separator: " ") + ")"
    }

    /// The transform that undoes an affine transform's six numbers; nil where it flattens the plane.
    static func inverse(_ numbers: [Double]) -> [Double]? {
        guard numbers.count == 6 else { return nil }
        let (a, b, c, d, e, f) = (numbers[0], numbers[1], numbers[2], numbers[3], numbers[4], numbers[5])
        let determinant = a * d - b * c
        guard determinant != 0, determinant.isFinite else { return nil }
        return [d / determinant, -b / determinant, -c / determinant, a / determinant,
                (c * f - d * e) / determinant, (b * e - a * f) / determinant]
    }

    /// A gradient SVG paints: its element, its geometry over `painted` in the page's own units, and its stops.
    struct Gradient {
        let id: String
        let tag: String
        let attributes: [(String, String)]
        let stops: [HostBrush.Stop]
    }

    /// The gradient `brush` is over `painted`; nil for a brush of one colour or none.
    static func gradient(_ brush: HostBrush, over painted: Rect, id: String) -> Gradient? {
        let n: (Double) -> String = WebCSS.number
        func x(_ share: Double) -> String { n(painted.x + share * painted.width) }
        func y(_ share: Double) -> String { n(painted.y + share * painted.height) }
        switch brush {
        case .none, .solid:
            return nil
        case .linear(let from, let to, let stops):
            return Gradient(id: id, tag: "linearGradient", attributes: [
                ("id", id), ("gradientUnits", "userSpaceOnUse"),
                ("x1", x(from.x)), ("y1", y(from.y)), ("x2", x(to.x)), ("y2", y(to.y)),
            ], stops: stops)
        case .radial(let center, let radius, let stops):
            let reach = HostBrush.reach(of: radius, width: painted.width, height: painted.height)
            return Gradient(id: id, tag: "radialGradient", attributes: [
                ("id", id), ("gradientUnits", "userSpaceOnUse"), ("cx", x(center.x)), ("cy", y(center.y)), ("r", n(reach)),
            ], stops: stops)
        }
    }
}
