// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A drawing as three flat lists, which a host's relay replays in one crossing.
/// Design: docs/design/types/drawing.md#three-lists-for-a-relay
@_spi(Host) public struct HostDrawing: Equatable, Sendable {
    /// Each instruction's kind, as `DrawCommand` numbers it, then its whole numbers: a colour as ARGB, a flag as 0
    /// or 1, an alignment as its member's number, a text's index in `strings`, a path's count of curves.
    public private(set) var ints: [Int32] = []

    /// Each instruction's numbers in order, a path's curves among them as `HostCurveCommand.numbers` lays them.
    public private(set) var numbers: [Double] = []

    /// What the instructions write.
    public private(set) var strings: [String] = []

    /// The instructions of `drawing` in order; one whose values do not read whole is left out.
    public init(_ drawing: [DrawCommand]) {
        for command in drawing { append(command) }
    }

    private mutating func append(_ command: DrawCommand) {
        let arguments = command.arguments
        let kind = command.kind.rawValue

        /// The first `count` arguments, when each is a finite number.
        func read(_ count: Int) -> [Double]? {
            let read = arguments.prefix(count).compactMap(\.number).filter(\.isFinite)
            return read.count == count ? read : nil
        }

        switch command.kind {
        case .fillColor, .strokeColor, .textColor:
            guard let channels = arguments.value(0)?.color else { return }
            let argb = UInt32(channels.alpha) << 24 | UInt32(channels.red) << 16
                | UInt32(channels.green) << 8 | UInt32(channels.blue)
            ints += [kind, Int32(bitPattern: argb)]
        case .strokeWidth, .fontSize, .alpha, .rotate:
            guard let read = read(1) else { return }
            ints.append(kind)
            numbers += read
        case .translate, .scale:
            guard let read = read(2) else { return }
            ints.append(kind)
            numbers += read
        case .drawLine, .drawRectangle, .drawEllipse, .fillRectangle, .fillEllipse:
            guard let read = read(4) else { return }
            ints.append(kind)
            numbers += read
        case .drawRoundedRectangle, .fillRoundedRectangle:
            guard let read = read(5) else { return }
            ints.append(kind)
            numbers += read
        case .drawArc:
            guard let read = read(6), let clockwise = arguments.value(6)?.bool,
                  let closed = arguments.value(7)?.bool
            else { return }
            ints += [kind, clockwise ? 1 : 0, closed ? 1 : 0]
            numbers += read
        case .fillArc:
            guard let read = read(6), let clockwise = arguments.value(6)?.bool else { return }
            ints += [kind, clockwise ? 1 : 0]
            numbers += read
        case .drawPath, .fillPath:
            guard let data = arguments.value(0)?.string else { return }
            let curves = HostPath(svg: data)?.arcsAsCubics ?? []
            ints += [kind, Int32(curves.count)]
            numbers += curves.flatMap(\.numbers)
        case .drawText:
            guard let read = read(4), let across = arguments.value(4)?.enumeration,
                  let down = arguments.value(5)?.enumeration, let text = arguments.value(6)?.string
            else { return }
            ints += [kind, across, down, Int32(strings.count)]
            numbers += read
            strings.append(text)
        case .saveState, .restoreState:
            ints.append(kind)
        }
    }
}
