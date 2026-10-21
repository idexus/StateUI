// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A canvas's drawing as three flat lists, which a host's relay replays in one crossing: its instructions as the host
/// layer reads them (`CanvasInstruction`), an arc as the curves it runs along (`CanvasArithmetic.arc`) - so no relay
/// works out an arc of its own.
/// Design: docs/design/types/drawing.md#three-lists-for-a-relay
@_spi(Host) public struct HostDrawing: Equatable, Sendable {
    /// Each instruction's kind, as `DrawCommand` numbers it, then its whole numbers: a color as ARGB, words' edge
    /// across their box (`TextEdge`) and their alignment down it as its member's number, a text's index in
    /// `strings`, a path's count of curves.
    public private(set) var ints: [Int32] = []

    /// Each instruction's numbers in order, a path's curves among them as `HostCurveCommand.numbers` lays them.
    public private(set) var numbers: [Double] = []

    /// What the instructions write.
    public private(set) var strings: [String] = []

    /// The instructions of `drawing` in order, after the size words stand at until the drawing sets one - the
    /// host's own body text - where one is given; an instruction whose values do not read whole is left out.
    public init(_ drawing: [DrawCommand], wordsSize: Double?) {
        if let wordsSize { record(Kind.fontSize, [wordsSize]) }
        for instruction in CanvasInstruction.instructions(drawing) { append(instruction) }
    }

    /// The numbers the kinds cross as, which a relay switches on.
    enum Kind: Int32 {
        case fillColor = 0, strokeColor = 1, textColor = 2
        case lineWidth = 3, fontSize = 4, opacity = 5
        case strokeLine = 6, strokeRectangle = 7, strokeRoundedRectangle = 8
        case strokeEllipse = 9, strokePath = 11
        case fillRectangle = 12, fillRoundedRectangle = 13, fillEllipse = 14
        case fillPath = 16, text = 17
        case translate = 18, rotate = 19, scale = 20
        case saveState = 21, restoreState = 22
    }

    private mutating func append(_ instruction: CanvasInstruction) {
        switch instruction {
        case .fillColor(let color): self.color(Kind.fillColor, color)
        case .strokeColor(let color): self.color(Kind.strokeColor, color)
        case .textColor(let color): self.color(Kind.textColor, color)
        case .lineWidth(let width): record(Kind.lineWidth, [width])
        case .fontSize(let size): record(Kind.fontSize, [size])
        case .opacity(let alpha): record(Kind.opacity, [alpha])
        case .strokeLine(let from, let to): record(Kind.strokeLine, [from.x, from.y, to.x, to.y])
        case .strokeRectangle(let rect): record(Kind.strokeRectangle, Self.numbers(rect))
        case .strokeRoundedRectangle(let rect, let radius): record(Kind.strokeRoundedRectangle, Self.numbers(rect) + [radius])
        case .strokeEllipse(let rect): record(Kind.strokeEllipse, Self.numbers(rect))
        case .strokeArc(let rect, let start, let end, let clockwise, let closed):
            path(Kind.strokePath, CanvasArithmetic.arc(
                in: rect, start: start, end: end, clockwise: clockwise, closed: closed, wedge: false))
        case .strokePath(let curves): path(Kind.strokePath, curves)
        case .fillRectangle(let rect): record(Kind.fillRectangle, Self.numbers(rect))
        case .fillRoundedRectangle(let rect, let radius): record(Kind.fillRoundedRectangle, Self.numbers(rect) + [radius])
        case .fillEllipse(let rect): record(Kind.fillEllipse, Self.numbers(rect))
        case .fillArc(let rect, let start, let end, let clockwise):
            path(Kind.fillPath, CanvasArithmetic.arc(
                in: rect, start: start, end: end, clockwise: clockwise, closed: true, wedge: true))
        case .fillPath(let curves): path(Kind.fillPath, curves)
        case .text(let text, let rect, let horizontal, let vertical):
            ints += [
                Kind.text.rawValue, CanvasArithmetic.wordsEdge(horizontal).rawValue, vertical.rawValue,
                Int32(strings.count),
            ]
            numbers += Self.numbers(rect)
            strings.append(text)
        case .translate(let x, let y): record(Kind.translate, [x, y])
        case .rotate(let degrees): record(Kind.rotate, [degrees])
        case .scale(let x, let y): record(Kind.scale, [x, y])
        case .saveState: ints.append(Kind.saveState.rawValue)
        case .restoreState: ints.append(Kind.restoreState.rawValue)
        }
    }

    private mutating func record(_ kind: Kind, _ values: [Double]) {
        ints.append(kind.rawValue)
        numbers += values
    }

    private mutating func color(_ kind: Kind, _ color: HostValue) {
        guard let argb = color.argb else { return }
        ints += [kind.rawValue, Int32(bitPattern: argb)]
    }

    private mutating func path(_ kind: Kind, _ curves: [HostCurveCommand]) {
        ints += [kind.rawValue, Int32(curves.count)]
        numbers += curves.flatMap(\.numbers)
    }

    private static func numbers(_ rect: Rect) -> [Double] {
        [rect.x, rect.y, rect.width, rect.height]
    }
}
