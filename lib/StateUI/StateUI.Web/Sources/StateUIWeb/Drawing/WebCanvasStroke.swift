// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A canvas's drawing as the relay replays it on a 2D context, in one call: numbers - each operation's code, then
/// what it takes - and the words it writes, by their place. Codes: 0 save, 1 restore, 2 translate x y, 3 rotate
/// radians, 4 scale x y, 5 begin a path, 6 move x y, 7 line x y, 8 cubic x1 y1 x2 y2 x y, 9 quadratic x1 y1 x y,
/// 10 close, 11 fill r g b a, 12 stroke r g b a width, 13 text word x y width height size r g b a across down.
/// Design: docs/design/platforms/web/drawing.md#a-canvas
struct WebCanvasStroke {
    private(set) var numbers: [Double] = []
    private(set) var words: [String] = []

    /// The drawing `instructions` replay by the host layer's rule (`CanvasPen.replay`).
    init(_ instructions: [CanvasInstruction]) {
        CanvasPen.replay(
            instructions, save: { numbers.append(0) }, restore: { numbers.append(1) },
            draw: { instruction, pen in draw(instruction, pen: pen) })
    }

    /// Draws `instruction` with `pen`: a shape outlined or filled in the pen's colours at its opacity, words in a
    /// room, or the drawing moved, turned or scaled from here.
    private mutating func draw(_ instruction: CanvasInstruction, pen: CanvasPen) {
        switch instruction {
        case .strokeLine(let from, let to): stroke([.move(from), .line(to)], pen)
        case .strokeRectangle(let room): stroke(Self.rounded(room, radius: 0), pen)
        case .strokeRoundedRectangle(let room, let radius): stroke(Self.rounded(room, radius: radius), pen)
        case .strokeEllipse(let room): stroke(Self.oval(room), pen)
        case .strokeArc(let room, let start, let end, let clockwise, let closed):
            stroke(CanvasArithmetic.arc(
                in: room, start: start, end: end, clockwise: clockwise, closed: closed, wedge: false), pen)
        case .strokePath(let curves): stroke(curves, pen)
        case .fillRectangle(let room): fill(Self.rounded(room, radius: 0), pen)
        case .fillRoundedRectangle(let room, let radius): fill(Self.rounded(room, radius: radius), pen)
        case .fillEllipse(let room): fill(Self.oval(room), pen)
        case .fillArc(let room, let start, let end, let clockwise):
            fill(CanvasArithmetic.arc(
                in: room, start: start, end: end, clockwise: clockwise, closed: true, wedge: true), pen)
        case .fillPath(let curves): fill(curves, pen)
        case .text(let text, let room, let across, let down):
            guard let color = Self.color(pen.text, pen) else { return }
            words.append(text)
            numbers += [13, Double(words.count - 1), room.x, room.y, room.width, room.height, pen.fontSize ?? 0]
                + color + [Self.code(across), Self.code(down)]
        case .translate(let x, let y): numbers += [2, x, y]
        case .rotate(let degrees): numbers += [3, degrees * .pi / 180]
        case .scale(let x, let y): numbers += [4, x, y]
        default: break
        }
    }

    private mutating func stroke(_ curves: [HostCurveCommand], _ pen: CanvasPen) {
        guard pen.lineWidth > 0, let color = Self.color(pen.stroke, pen) else { return }
        path(curves)
        numbers += [12] + color + [pen.lineWidth]
    }

    private mutating func fill(_ curves: [HostCurveCommand], _ pen: CanvasPen) {
        guard let color = Self.color(pen.fill, pen) else { return }
        path(curves)
        numbers += [11] + color
    }

    private mutating func path(_ curves: [HostCurveCommand]) {
        numbers.append(5)
        for curve in curves {
            switch curve {
            case .move(let to): numbers += [6, to.x, to.y]
            case .line(let to): numbers += [7, to.x, to.y]
            case .cubic(let first, let second, let end):
                numbers += [8, first.x, first.y, second.x, second.y, end.x, end.y]
            case .quadratic(let control, let end): numbers += [9, control.x, control.y, end.x, end.y]
            case .close: numbers.append(10)
            }
        }
    }

    /// A colour's red, green and blue from 0 to 255 and its opacity from 0 to 1, at the pen's opacity; nil for none.
    private static func color(_ value: HostValue, _ pen: CanvasPen) -> [Double]? {
        guard let color = value.color else { return nil }
        return [Double(color.red), Double(color.green), Double(color.blue), Double(color.alpha) / 255 * pen.alpha]
    }

    private static func code(_ alignment: TextAlignment) -> Double {
        alignment == .center ? 1 : alignment == .end ? 2 : 0
    }

    /// A rectangle, its corners rounded by `radius` as far as the rectangle holds.
    static func rounded(_ room: Rect, radius: Double) -> [HostCurveCommand] {
        let kept = BoxArithmetic.fitted(max(0, radius), width: room.width, height: room.height)
        return outline(room, corner: kept)
    }

    /// The ellipse a rectangle holds.
    static func oval(_ room: Rect) -> [HostCurveCommand] {
        outline(room, corner: (room.width / 2, room.height / 2))
    }

    /// A rectangle with its four corners quarters of an ellipse `corner` across and down, each a cubic.
    private static func outline(_ room: Rect, corner: (width: Double, height: Double)) -> [HostCurveCommand] {
        let (x, y, right, bottom) = (room.x, room.y, room.x + room.width, room.y + room.height)
        let (rx, ry) = (corner.width, corner.height)
        // How far a quarter's control points stand from its ends, as a share of its radius.
        let k = 0.5522847498
        guard rx > 0, ry > 0 else {
            return [.move(Point(x: x, y: y)), .line(Point(x: right, y: y)), .line(Point(x: right, y: bottom)),
                    .line(Point(x: x, y: bottom)), .close]
        }
        func p(_ a: Double, _ b: Double) -> Point { Point(x: a, y: b) }
        return [
            .move(p(x + rx, y)), .line(p(right - rx, y)),
            .cubic(control1: p(right - rx + rx * k, y), control2: p(right, y + ry - ry * k), end: p(right, y + ry)),
            .line(p(right, bottom - ry)),
            .cubic(
                control1: p(right, bottom - ry + ry * k), control2: p(right - rx + rx * k, bottom),
                end: p(right - rx, bottom)),
            .line(p(x + rx, bottom)),
            .cubic(control1: p(x + rx - rx * k, bottom), control2: p(x, bottom - ry + ry * k), end: p(x, bottom - ry)),
            .line(p(x, y + ry)),
            .cubic(control1: p(x, y + ry - ry * k), control2: p(x + rx - rx * k, y), end: p(x + rx, y)),
            .close,
        ]
    }
}
