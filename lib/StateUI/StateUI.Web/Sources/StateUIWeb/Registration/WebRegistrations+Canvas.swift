// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A Canvas: its drawing replayed on a `<canvas>`; a press on it is a view's, heard as every view hears one.
    static func canvas(_ registry: Registry<WebDOMView>) {
        registry.add(CanvasContract.self, create: { _ in WebCanvasView() }, members: { canvas in
            canvas.property(CanvasContract.drawing) { view, drawing in view.apply(drawing) }
        })
    }
}
