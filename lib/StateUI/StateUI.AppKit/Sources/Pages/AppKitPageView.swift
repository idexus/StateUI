// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's view, or a popover's: what it holds stands in its whole view, on its background - a color its layer
/// paints, a gradient it draws across itself.
/// Design: docs/design/platforms/appkit/views.md#a-pages-background
@MainActor
final class AppKitPageView: AppKitSingleChildView {
    /// The gradient the view draws across its whole bounds; empty where its layer paints a color, or nothing.
    var gradient = AppKitBrush() {
        didSet { if gradient != oldValue { needsDisplay = true } }
    }

    /// A color, or nothing, is its layer's, with no backing store; only a gradient draws.
    override var wantsUpdateLayer: Bool { !gradient.paints }

    override func updateLayer() {}

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        gradient.draw(in: NSBezierPath(rect: bounds), bounds: bounds)
    }
}

#endif
