// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A canvas's drawing as three flat lists, which a host's relay replays in one crossing: its instructions as the host
/// layer reads them (`CanvasInstruction`), an arc as the curves it runs along (`CanvasArithmetic.arc`) - so no relay
/// works out an arc of its own.
/// Design: docs/design/types/drawing.md#three-lists-for-a-relay
@_spi(Host) public struct HostDrawing: Equatable, Sendable {
    /// Each instruction's kind, as `DrawCommand` numbers it, then its whole numbers: a colour as ARGB, an alignment
    /// as its member's number, a text's index in `strings`, a path's count of curves.
    public private(set) var ints: [Int32] = []

    /// Each instruction's numbers in order, a path's curves among them as `HostCurveCommand.numbers` lays them.
    public private(set) var numbers: [Double] = []

    /// What the instructions write.
    public private(set) var strings: [String] = []

    /// The instructions of `drawing` in order; one whose values do not read whole is left out.
    public init(_ drawing: [DrawCommand]) {
        for instruction in CanvasInstruction.instructions(drawing) { append(instruction) }
    }

    /// The numbers the kinds cross as, which a relay switches on.
    private enum Kind {
        static let fillColor: Int32 = 0, strokeColor: Int32 = 1, textColor: Int32 = 2
        static let strokeWidth: Int32 = 3, fontSize: Int32 = 4, alpha: Int32 = 5
        static let drawLine: Int32 = 6, drawRectangle: Int32 = 7, drawRoundedRectangle: Int32 = 8
        static let drawEllipse: Int32 = 9, drawPath: Int32 = 11
        static let fillRectangle: Int32 = 12, fillRoundedRectangle: Int32 = 13, fillEllipse: Int32 = 14
        static let fillPath: Int32 = 16, drawText: Int32 = 17
        static let translate: Int32 = 18, rotate: Int32 = 19, scale: Int32 = 20
        static let saveState: Int32 = 21, restoreState: Int32 = 22
    }

    private mutating func append(_ instruction: CanvasInstruction) {
        switch instruction {
        case .fillColor(let color): colour(Kind.fillColor, color)
        case .strokeColor(let color): colour(Kind.strokeColor, color)
        case .textColor(let color): colour(Kind.textColor, color)
        case .strokeWidth(let width): record(Kind.strokeWidth, [width])
        case .fontSize(let size): record(Kind.fontSize, [size])
        case .alpha(let alpha): record(Kind.alpha, [alpha])
        case .drawLine(let from, let to): record(Kind.drawLine, [from.x, from.y, to.x, to.y])
        case .drawRectangle(let rect): record(Kind.drawRectangle, Self.numbers(rect))
        case .drawRoundedRectangle(let rect, let radius): record(Kind.drawRoundedRectangle, Self.numbers(rect) + [radius])
        case .drawEllipse(let rect): record(Kind.drawEllipse, Self.numbers(rect))
        case .drawArc(let rect, let start, let end, let clockwise, let closed):
            path(Kind.drawPath, CanvasArithmetic.arc(
                in: rect, start: start, end: end, clockwise: clockwise, closed: closed, wedge: false))
        case .drawPath(let curves): path(Kind.drawPath, curves)
        case .fillRectangle(let rect): record(Kind.fillRectangle, Self.numbers(rect))
        case .fillRoundedRectangle(let rect, let radius): record(Kind.fillRoundedRectangle, Self.numbers(rect) + [radius])
        case .fillEllipse(let rect): record(Kind.fillEllipse, Self.numbers(rect))
        case .fillArc(let rect, let start, let end, let clockwise):
            path(Kind.fillPath, CanvasArithmetic.arc(
                in: rect, start: start, end: end, clockwise: clockwise, closed: true, wedge: true))
        case .fillPath(let curves): path(Kind.fillPath, curves)
        case .drawText(let text, let rect, let horizontal, let vertical):
            ints += [Kind.drawText, horizontal.rawValue, vertical.rawValue, Int32(strings.count)]
            numbers += Self.numbers(rect)
            strings.append(text)
        case .translate(let x, let y): record(Kind.translate, [x, y])
        case .rotate(let degrees): record(Kind.rotate, [degrees])
        case .scale(let x, let y): record(Kind.scale, [x, y])
        case .saveState: ints.append(Kind.saveState)
        case .restoreState: ints.append(Kind.restoreState)
        }
    }

    private mutating func record(_ kind: Int32, _ values: [Double]) {
        ints.append(kind)
        numbers += values
    }

    private mutating func colour(_ kind: Int32, _ color: HostValue) {
        guard let argb = color.argb else { return }
        ints += [kind, Int32(bitPattern: argb)]
    }

    private mutating func path(_ kind: Int32, _ curves: [HostCurveCommand]) {
        ints += [kind, Int32(curves.count)]
        numbers += curves.flatMap(\.numbers)
    }

    private static func numbers(_ rect: Rect) -> [Double] {
        [rect.x, rect.y, rect.width, rect.height]
    }
}
