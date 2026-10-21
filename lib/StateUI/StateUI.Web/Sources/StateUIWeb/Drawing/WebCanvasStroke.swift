// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A canvas's drawing as the relay replays it on a 2D context, in one call: numbers - each operation, then what it
/// takes - and the words it writes, by their place.
/// Design: docs/design/platforms/web/drawing.md#a-canvas
struct WebCanvasStroke {
    private(set) var numbers: [Double] = []
    private(set) var words: [String] = []

    /// An operation of the drawing; what follows it in the numbers stands beside each.
    enum Operation: Int32 {
        case save = 0
        case restore
        case translate  // x y
        case rotate  // radians
        case scale  // x y
        case beginPath
        case move  // x y
        case line  // x y
        case cubic  // x1 y1 x2 y2 x y
        case quadratic  // x1 y1 x y
        case close
        case fill  // r g b a
        case stroke  // r g b a width
        case text  // word x y width height size lineHeight r g b a edge anchor down
    }

    /// The drawing `instructions` replay by the host layer's rule (`CanvasPen.replay`).
    init(_ instructions: [CanvasInstruction]) {
        CanvasPen.replay(
            instructions, save: { numbers.append(Self.code(.save)) }, restore: { numbers.append(Self.code(.restore)) },
            draw: { instruction, pen in draw(instruction, pen: pen) })
    }

    /// Draws `instruction` with `pen`: a shape outlined or filled in the pen's colors at its opacity, words in a
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
            // The size of body text until the drawing sets one; the edge and its point as the host layer places them.
            let size = pen.fontSize ?? TextStyle.body.webSize
            let edge = CanvasArithmetic.wordsEdge(across)
            numbers += [Self.code(.text), Double(words.count - 1), room.x, room.y, room.width, room.height]
                + [size, size * WebCSS.lineHeight] + color
                + [Double(edge.rawValue), CanvasArithmetic.wordsAnchor(edge, in: room), Double(down.rawValue)]
        case .translate(let x, let y): numbers += [Self.code(.translate), x, y]
        case .rotate(let degrees): numbers += [Self.code(.rotate), degrees * .pi / 180]
        case .scale(let x, let y): numbers += [Self.code(.scale), x, y]
        default: break
        }
    }

    private mutating func stroke(_ curves: [HostCurveCommand], _ pen: CanvasPen) {
        guard pen.lineWidth > 0, let color = Self.color(pen.stroke, pen) else { return }
        path(curves)
        numbers += [Self.code(.stroke)] + color + [pen.lineWidth]
    }

    private mutating func fill(_ curves: [HostCurveCommand], _ pen: CanvasPen) {
        guard let color = Self.color(pen.fill, pen) else { return }
        path(curves)
        numbers += [Self.code(.fill)] + color
    }

    private mutating func path(_ curves: [HostCurveCommand]) {
        numbers.append(Self.code(.beginPath))
        for curve in curves {
            switch curve {
            case .move(let to): numbers += [Self.code(.move), to.x, to.y]
            case .line(let to): numbers += [Self.code(.line), to.x, to.y]
            case .cubic(let first, let second, let end):
                numbers += [Self.code(.cubic), first.x, first.y, second.x, second.y, end.x, end.y]
            case .quadratic(let control, let end):
                numbers += [Self.code(.quadratic), control.x, control.y, end.x, end.y]
            case .close: numbers.append(Self.code(.close))
            }
        }
    }

    /// A color's red, green and blue from 0 to 255 and its opacity from 0 to 1, at the pen's opacity; nil for none.
    private static func color(_ value: HostValue, _ pen: CanvasPen) -> [Double]? {
        guard let color = value.color else { return nil }
        return [Double(color.red), Double(color.green), Double(color.blue),
                ColorComponent.fraction(color.alpha) * pen.alpha]
    }

    private static func code(_ operation: Operation) -> Double {
        Double(operation.rawValue)
    }

    /// A rectangle, its corners rounded by `radius` - kept within its sides as the instruction is read.
    static func rounded(_ room: Rect, radius: Double) -> [HostCurveCommand] {
        outline(room, corner: (radius, radius))
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
