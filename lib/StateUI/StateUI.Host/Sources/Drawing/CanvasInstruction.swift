// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One instruction of a canvas's drawing as a host drawing in Swift replays it, read from the record it crosses as -
/// the same on every such host; a record that does not read whole is left out.
/// Design: docs/design/types/drawing.md#a-drawing-is-a-list-of-records
@_spi(Host) public enum CanvasInstruction: Equatable, Sendable {
    /// The colour fills are drawn in from here.
    case fillColor(HostValue)
    /// The colour outlines are drawn in from here.
    case strokeColor(HostValue)
    /// The colour text is drawn in from here.
    case textColor(HostValue)
    /// An outline's width from here.
    case lineWidth(Double)
    /// The text's size in points from here.
    case fontSize(Double)
    /// How opaque everything is drawn from here, from nothing to whole.
    case opacity(Double)
    /// Outlines a line between two points.
    case strokeLine(from: Point, to: Point)
    /// Outlines a rectangle.
    case strokeRectangle(Rect)
    /// Outlines a rectangle with its corners rounded by the radius.
    case strokeRoundedRectangle(Rect, radius: Double)
    /// Outlines the ellipse a rectangle holds.
    case strokeEllipse(Rect)
    /// Outlines an arc of the ellipse a rectangle holds, from one angle to another in degrees - closed back to its
    /// start where it says so.
    case strokeArc(Rect, start: Double, end: Double, clockwise: Bool, closed: Bool)
    /// Outlines a path.
    case strokePath([HostCurveCommand])
    /// Fills a rectangle.
    case fillRectangle(Rect)
    /// Fills a rectangle with its corners rounded by the radius.
    case fillRoundedRectangle(Rect, radius: Double)
    /// Fills the ellipse a rectangle holds.
    case fillEllipse(Rect)
    /// Fills the slice of the ellipse a rectangle holds between two angles in degrees.
    case fillArc(Rect, start: Double, end: Double, clockwise: Bool)
    /// Fills a path.
    case fillPath([HostCurveCommand])
    /// Writes text in a rectangle, placed across and down it as the alignments say.
    case text(String, in: Rect, horizontal: TextAlignment, vertical: TextAlignment)
    /// Moves what is drawn from here by a distance.
    case translate(x: Double, y: Double)
    /// Turns what is drawn from here by degrees.
    case rotate(degrees: Double)
    /// Scales what is drawn from here along each axis.
    case scale(x: Double, y: Double)
    /// Remembers the settings and the movement as they are.
    case saveState
    /// Puts back the settings and the movement remembered last.
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
        case 3: guard let n = numbers(1) else { return nil }; self = .lineWidth(n[0])
        case 4: guard let n = numbers(1) else { return nil }; self = .fontSize(n[0])
        case 5: guard let n = numbers(1) else { return nil }; self = .opacity(n[0])
        case 6:
            guard let n = numbers(4) else { return nil }
            self = .strokeLine(from: Point(x: n[0], y: n[1]), to: Point(x: n[2], y: n[3]))
        case 7: guard let r = rect() else { return nil }; self = .strokeRectangle(r)
        case 8: guard let r = rect(), let n = numbers(5) else { return nil }; self = .strokeRoundedRectangle(r, radius: n[4])
        case 9: guard let r = rect() else { return nil }; self = .strokeEllipse(r)
        case 10:
            guard let r = rect(), let n = numbers(6), let clockwise = flag(6), let closed = flag(7) else { return nil }
            self = .strokeArc(r, start: n[4], end: n[5], clockwise: clockwise, closed: closed)
        case 11: guard let c = curves() else { return nil }; self = .strokePath(c)
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
            self = .text(
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
