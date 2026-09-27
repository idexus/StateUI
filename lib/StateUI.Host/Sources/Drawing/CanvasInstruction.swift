// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One instruction of a canvas's drawing as a host drawing in Swift replays it, read from the record it crosses as -
/// the same on every such host; a record that does not read whole is left out.
/// Design: docs/design/types/drawing.md#a-drawing-is-a-list-of-records
@_spi(Host) public enum CanvasInstruction: Equatable, Sendable {
    case fillColor(HostValue)
    case strokeColor(HostValue)
    case textColor(HostValue)
    case strokeWidth(Double)
    case fontSize(Double)
    case alpha(Double)
    case drawLine(from: Point, to: Point)
    case drawRectangle(Rect)
    case drawRoundedRectangle(Rect, radius: Double)
    case drawEllipse(Rect)
    case drawArc(Rect, start: Double, end: Double, clockwise: Bool, closed: Bool)
    case drawPath([HostCurveCommand])
    case fillRectangle(Rect)
    case fillRoundedRectangle(Rect, radius: Double)
    case fillEllipse(Rect)
    case fillArc(Rect, start: Double, end: Double, clockwise: Bool)
    case fillPath([HostCurveCommand])
    case drawText(String, in: Rect, horizontal: TextAlignment, vertical: TextAlignment)
    case translate(x: Double, y: Double)
    case rotate(degrees: Double)
    case scale(x: Double, y: Double)
    case saveState
    case restoreState

    /// The instructions of `drawing`, in order.
    public static func instructions(_ drawing: [DrawCommand]?) -> [CanvasInstruction] {
        (drawing ?? []).compactMap { CanvasInstruction($0.propValue) }
    }

    /// The instruction a record says; nil for one that does not read whole.
    init?(_ record: PropValue) {
        guard let parts = record.values, let kind = parts.first?.enumeration else { return nil }
        let values = Array(parts.dropFirst())
        func numbers(_ count: Int) -> [Double]? {
            guard values.count >= count else { return nil }
            let read = values.prefix(count).compactMap(\.number)
            return read.count == count && read.allSatisfy(\.isFinite) ? read : nil
        }
        func rect() -> Rect? { numbers(4).map { Rect(x: $0[0], y: $0[1], width: $0[2], height: $0[3]) } }
        func flag(_ index: Int) -> Bool? { values.indices.contains(index) ? values[index].bool : nil }
        func curves() -> [HostCurveCommand]? { values.first?.string.flatMap { HostPath(svg: $0)?.arcsAsCubics } }

        switch kind {
        case 0: guard let color = values.first, color.color != nil else { return nil }; self = .fillColor(color)
        case 1: guard let color = values.first, color.color != nil else { return nil }; self = .strokeColor(color)
        case 2: guard let color = values.first, color.color != nil else { return nil }; self = .textColor(color)
        case 3: guard let n = numbers(1) else { return nil }; self = .strokeWidth(n[0])
        case 4: guard let n = numbers(1) else { return nil }; self = .fontSize(n[0])
        case 5: guard let n = numbers(1) else { return nil }; self = .alpha(n[0])
        case 6:
            guard let n = numbers(4) else { return nil }
            self = .drawLine(from: Point(x: n[0], y: n[1]), to: Point(x: n[2], y: n[3]))
        case 7: guard let r = rect() else { return nil }; self = .drawRectangle(r)
        case 8: guard let r = rect(), let n = numbers(5) else { return nil }; self = .drawRoundedRectangle(r, radius: n[4])
        case 9: guard let r = rect() else { return nil }; self = .drawEllipse(r)
        case 10:
            guard let r = rect(), let n = numbers(6), let clockwise = flag(6), let closed = flag(7) else { return nil }
            self = .drawArc(r, start: n[4], end: n[5], clockwise: clockwise, closed: closed)
        case 11: guard let c = curves() else { return nil }; self = .drawPath(c)
        case 12: guard let r = rect() else { return nil }; self = .fillRectangle(r)
        case 13: guard let r = rect(), let n = numbers(5) else { return nil }; self = .fillRoundedRectangle(r, radius: n[4])
        case 14: guard let r = rect() else { return nil }; self = .fillEllipse(r)
        case 15:
            guard let r = rect(), let n = numbers(6), let clockwise = flag(6) else { return nil }
            self = .fillArc(r, start: n[4], end: n[5], clockwise: clockwise)
        case 16: guard let c = curves() else { return nil }; self = .fillPath(c)
        case 17:
            guard let r = rect(), values.count >= 7, let across = values[4].enumeration, let down = values[5].enumeration,
                  let text = values[6].string
            else { return nil }
            self = .drawText(
                text, in: r, horizontal: TextAlignment(rawValue: across) ?? .start,
                vertical: TextAlignment(rawValue: down) ?? .start)
        case 18: guard let n = numbers(2) else { return nil }; self = .translate(x: n[0], y: n[1])
        case 19: guard let n = numbers(1) else { return nil }; self = .rotate(degrees: n[0])
        case 20: guard let n = numbers(2) else { return nil }; self = .scale(x: n[0], y: n[1])
        case 21: self = .saveState
        case 22: self = .restoreState
        default: return nil
        }
    }
}
