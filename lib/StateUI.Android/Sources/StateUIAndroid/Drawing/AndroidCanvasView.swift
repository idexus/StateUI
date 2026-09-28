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

    /// The drawing, its instructions in the order they were written, as the host layer lays them out; nil draws
    /// nothing.
    func draw(_ drawing: [DrawCommand]?) {
        let drawing = HostDrawing(drawing ?? [])
        Java.frame {
            Java.call(
                reference, JavaAPI.setDrawing, .object(Java.ints(drawing.ints)),
                .object(Java.floats(drawing.numbers.map(Float.init))),
                .object(Java.array(of: JavaAPI.string, drawing.strings.map(Java.string))))
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
}
