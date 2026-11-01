// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A Canvas: its drawing; a finger on it is a view's, heard as every view hears one.
    static func drawing(_ registry: Registry<AndroidView>) {
        registry.add(CanvasContract.self, create: { _ in AndroidCanvasView() }, members: { canvas in
            canvas.property(CanvasContract.drawing) { view, drawing in view.draw(drawing) }
        })
    }
}
