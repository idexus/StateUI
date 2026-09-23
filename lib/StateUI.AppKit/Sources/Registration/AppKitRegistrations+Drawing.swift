// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

extension AppKitRegistrations {
    /// The surface an application draws on, and the finger it answers.
    ///
    /// A drawing is ONE value that replaces the one before it, so the canvas
    /// takes it whole rather than instruction by instruction. The three
    /// reports carry where the finger was, in the canvas's own coordinates -
    /// the ones the instructions use.
    static func drawing(_ registry: Registry<NSView>) {
        registry.add(CanvasContract.self, create: { reports in
            let canvas = AppKitCanvasView()
            canvas.onPressed = { point in
                reports.raise(CanvasContract.pressed, Point(x: point.x, y: point.y))
            }
            canvas.onDragged = { point in
                reports.raise(CanvasContract.dragged, Point(x: point.x, y: point.y))
            }
            canvas.onReleased = { point in
                reports.raise(CanvasContract.released, Point(x: point.x, y: point.y))
            }
            return canvas
        }, members: { canvas in
            canvas.property(CanvasContract.drawable) { view, drawing in
                view.apply(drawing)
            }
            canvas.raises(CanvasContract.pressed)
            canvas.raises(CanvasContract.dragged)
            canvas.raises(CanvasContract.released)
        })
    }
}

#endif
