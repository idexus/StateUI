// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// The surface an application draws on.
    ///
    /// A drawing is ONE value that replaces the one before it, so the canvas
    /// takes it whole rather than instruction by instruction; a press on it is
    /// a view's, heard as every view hears one.
    static func drawing(_ registry: Registry<NSView>) {
        registry.add(CanvasContract.self, create: { _ in
            AppKitCanvasView()
        }, members: { canvas in
            canvas.property(CanvasContract.drawing) { view, drawing in
                view.apply(drawing)
            }
        })
    }
}

#endif
