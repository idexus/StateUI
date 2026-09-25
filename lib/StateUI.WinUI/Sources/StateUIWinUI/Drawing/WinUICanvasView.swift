// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIWinUI

/// A Canvas: the relay's panel, which replays the drawing with Direct2D; the whole drawing crosses in one call.
/// Design: docs/design/platforms/winui/drawing.md#a-canvas
@MainActor
final class WinUICanvasView: WinUIView {
    /// What the canvas does as a press goes down on it, moves, and is lifted, at a point in DIPs of it.
    var onPressed: ((Point) -> Void)?
    var onDragged: ((Point) -> Void)?
    var onReleased: ((Point) -> Void)?

    init() {
        super.init { number in stateui_winui_canvas_make(number) }
    }

    /// The drawing, its instructions in the order they were written; nil draws nothing.
    func draw(_ drawing: [DrawCommand]?) {
        let flat = HostDrawing(drawing ?? [])
        let words = flat.strings.flatMap { $0.utf8.map { CChar(bitPattern: $0) } }
        let lengths = flat.strings.map { Int32($0.utf8.count) }
        flat.ints.withUnsafeBufferPointer { ints in
            flat.numbers.withUnsafeBufferPointer { numbers in
                words.withUnsafeBufferPointer { words in
                    lengths.withUnsafeBufferPointer { lengths in
                        stateui_winui_canvas_draw(
                            handle, ints.baseAddress, Int32(ints.count), numbers.baseAddress, Int32(numbers.count),
                            words.baseAddress, lengths.baseAddress, Int32(lengths.count))
                    }
                }
            }
        }
    }

    /// A press on the canvas at `point`, in its phase: 0 pressed, 1 dragged, 2 released.
    func pressed(phase: Int32, at point: Point) {
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
