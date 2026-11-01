// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension GTKRegistrations {
    /// A Canvas: its drawing replayed on GTK's snapshot; a press on it is a view's, heard as every view hears one.
    static func canvas(_ registry: Registry<GTKView>) {
        registry.add(CanvasContract.self, create: { _ in GTKCanvasView() }, members: { canvas in
            canvas.property(CanvasContract.drawing) { view, drawing in view.apply(drawing) }
        })
    }
}
