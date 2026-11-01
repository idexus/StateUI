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
    init() {
        super.init { number in
            Java.new(
                JavaAPI.canvasView, JavaAPI.newCanvasView, .object(AndroidRenderer.context), .long(number),
                .float(Float(AndroidRenderer.density)))
        }
    }

    /// The drawing, its instructions in the order they were written, as the host layer lays them out - its words
    /// at the size of body text until it sets one; nil draws nothing.
    func draw(_ drawing: [DrawCommand]?) {
        let drawing = HostDrawing(drawing ?? [], wordsSize: TextStyle.body.androidSize)
        Java.frame {
            Java.call(
                reference, JavaAPI.setDrawing, .object(Java.ints(drawing.ints)),
                .object(Java.floats(drawing.numbers.map(Float.init))),
                .object(Java.strings(drawing.strings)))
        }
    }
}
