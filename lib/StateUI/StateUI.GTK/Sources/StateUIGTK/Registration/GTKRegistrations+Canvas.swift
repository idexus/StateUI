// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A Canvas: its drawing replayed on GTK's snapshot, and a press, its drag and its release told where they are.
    static func canvas(_ registry: Registry<GTKView>) {
        registry.add(CanvasContract.self, create: { reports in
            let canvas = GTKCanvasView()
            canvas.onPressed = { reports.raise(CanvasContract.pressed, $0) }
            canvas.onDragged = { reports.raise(CanvasContract.dragged, $0) }
            canvas.onReleased = { reports.raise(CanvasContract.released, $0) }
            return canvas
        }, members: { canvas in
            canvas.property(CanvasContract.drawing) { view, drawing in view.apply(drawing) }
            canvas.raises(CanvasContract.pressed)
            canvas.raises(CanvasContract.dragged)
            canvas.raises(CanvasContract.released)
        })
    }
}
