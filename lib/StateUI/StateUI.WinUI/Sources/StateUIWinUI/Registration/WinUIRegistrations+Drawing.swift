// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// A Canvas: its drawing; a press on it is a view's, heard as every view hears one.
    static func drawing(_ registry: Registry<WinUIView>) {
        registry.add(CanvasContract.self, create: { _ in WinUICanvasView() }, members: { canvas in
            canvas.property(CanvasContract.drawing) { view, drawing in view.draw(drawing) }
        })
    }
}
