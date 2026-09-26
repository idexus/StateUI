// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A Canvas: the host's `StateUICanvasView`, which replays the drawing's instructions in points; the whole
/// drawing crosses in one call.
/// Design: docs/design/platforms/android/drawing.md#a-canvas
@MainActor
final class AndroidCanvasView: AndroidView {
    /// What the canvas does as a finger goes down on it, moves, and is lifted, at a point in points.
    var onPressed: ((Point) -> Void)?
    var onDragged: ((Point) -> Void)?
    var onReleased: ((Point) -> Void)?

    init() {
        super.init { number in
            Java.new(
                JavaAPI.canvasView, JavaAPI.newCanvasView, .object(AndroidRenderer.context), .long(number),
                .float(Float(AndroidRenderer.density)))
        }
    }

    /// The drawing, its instructions in the order they were written; nil draws nothing.
    func draw(_ drawing: [DrawCommand]?) {
        let (ints, numbers, strings) = Self.encoded(drawing ?? [])
        Java.frame {
            Java.call(
                reference, JavaAPI.setDrawing, .object(Java.ints(ints)), .object(Java.floats(numbers)),
                .object(Java.array(of: JavaAPI.string, strings.map(Java.string))))
        }
    }

    /// A finger's phase - down, moved, lifted - at `point`.
    func touched(phase: Int32, at point: Point) {
        switch phase {
        case 0: onPressed?(point)
        case 1: onDragged?(point)
        default: onReleased?(point)
        }
    }

    override func detach() {
        super.detach()
        onPressed = nil
        onDragged = nil
        onReleased = nil
    }

    /// The instructions as the Java side reads them: each kind followed by its colours, flags and text
    /// indices as ints, its numbers as floats, its text as strings. A record that does not read whole is
    /// left out, as every host leaves it out; a path's arcs come as the shared parser's curves.
    static func encoded(_ drawing: [DrawCommand]) -> ([Int32], [Float], [String]) {
        var ints: [Int32] = []
        var numbers: [Float] = []
        var strings: [String] = []

        for command in drawing {
            guard let record = command.propValue.values, let kind = record.first?.enumeration else { continue }
            func values(_ count: Int) -> [Float]? {
                guard record.count > count else { return nil }
                let read = record[1...count].compactMap { $0.number }.filter(\.isFinite)
                return read.count == count ? read.map(Float.init) : nil
            }

            switch kind {
            case 0, 1, 2:
                guard let argb = record.value(1).flatMap(AndroidView.argb) else { continue }
                ints += [kind, argb]
            case 3, 4, 5, 19:
                guard let read = values(1) else { continue }
                ints.append(kind)
                numbers += read
            case 18, 20:
                guard let read = values(2) else { continue }
                ints.append(kind)
                numbers += read
            case 6, 7, 9, 12, 14:
                guard let read = values(4) else { continue }
                ints.append(kind)
                numbers += read
            case 8, 13:
                guard let read = values(5) else { continue }
                ints.append(kind)
                numbers += read
            case 10, 15:
                guard let read = values(6), let clockwise = record.value(7)?.bool else { continue }
                let closed = kind == 10 ? record.value(8)?.bool : false
                guard let closed else { continue }
                ints += [kind, clockwise ? 1 : 0] + (kind == 10 ? [closed ? 1 : 0] : [])
                numbers += read
            case 11, 16:
                guard let data = record.value(1)?.string else { continue }
                let curves = HostPath(svg: data)?.arcsAsCubics ?? []
                ints += [kind, Int32(curves.count)]
                numbers += curves.flatMap(Self.numbers)
            case 17:
                guard let read = values(4), let horizontal = record.value(5)?.enumeration,
                      let vertical = record.value(6)?.enumeration, let text = record.value(7)?.string
                else { continue }
                ints += [kind, horizontal, vertical, Int32(strings.count)]
                numbers += read
                strings.append(text)
            case 21, 22:
                ints.append(kind)
            default:
                continue
            }
        }
        return (ints, numbers, strings)
    }

    /// One curve command as the Java side reads it: its kind, then its points.
    private static func numbers(_ command: HostCurveCommand) -> [Float] {
        func at(_ point: Point) -> [Float] { [Float(point.x), Float(point.y)] }
        return switch command {
        case .move(let point): [0] + at(point)
        case .line(let point): [1] + at(point)
        case .cubic(let first, let second, let end): [2] + at(first) + at(second) + at(end)
        case .quadratic(let control, let end): [3] + at(control) + at(end)
        case .close: [4]
        }
    }
}
