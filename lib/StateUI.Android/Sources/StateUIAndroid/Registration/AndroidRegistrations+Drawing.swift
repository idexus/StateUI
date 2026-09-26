// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A Canvas: its drawing, and a finger's press, drag and release on it.
    static func drawing(_ registry: Registry<AndroidView>) {
        registry.add(CanvasContract.self, create: { reports in
            let canvas = AndroidCanvasView()
            canvas.onPressed = { reports.raise(CanvasContract.pressed, $0) }
            canvas.onDragged = { reports.raise(CanvasContract.dragged, $0) }
            canvas.onReleased = { reports.raise(CanvasContract.released, $0) }
            return canvas
        }, members: { canvas in
            canvas.property(CanvasContract.drawable) { view, drawing in view.draw(drawing) }
            canvas.raises(CanvasContract.pressed)
            canvas.raises(CanvasContract.dragged)
            canvas.raises(CanvasContract.released)
        })
    }
}
