// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One pane of a split view. Its page keeps out of the part the window's title
/// bar and toolbar cover, and the brush written for the bars paints that part;
/// a sidebar's pane stands on the material its split view says, else on the
/// system's sidebar.
///
/// A room: the split view decides its size and it gives its page all of it, so
/// a change inside the page is laid out by the page.
@MainActor
final class AppKitPaneView: AppKitSingleChildView, AppKitRoom {
    /// What the window's bars are painted with - a color or a gradient - over `barBand`.
    var barBrush = AppKitBrush() {
        didSet { if barBrush != oldValue { needsDisplay = true } }
    }

    /// What the pane stands on - a color, a gradient, a blur or glass - drawn as a layout draws its box.
    let ground = AppKitDecoration()

    /// Stands the pane on `background`, the split view's material; nil leaves the system's own.
    func showGround(_ background: HostValue?) {
        ground.apply(background: background, stroke: nil, lineWidth: nil, shape: nil, clips: false, to: self)
    }

    /// The part of this pane the window's title bar and toolbar cover.
    var barBand: NSRect {
        NSRect(x: 0, y: 0, width: bounds.width, height: max(0, safeAreaRect.minY))
    }

    override func layout() {
        super.layout()
        if barBrush.paints { needsDisplay = true }
        layOutReporting(item?.view)
    }

    /// The whole of the view under a transform, which AppKit leaves out of what it takes for visible.
    override var visibleRect: NSRect { drawnRect(visible: super.visibleRect) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        ground.draw(in: bounds)
        guard barBrush.paints else { return }
        // Design: docs/design/platforms/appkit/runtime.md#the-bars-band
        let window = self.window?.contentView.map { convert($0.bounds, from: $0) } ?? bounds
        let across = NSRect(x: window.minX, y: barBand.minY, width: window.width, height: barBand.height)
        barBrush.draw(in: NSBezierPath(rect: barBand), bounds: across)
    }
}

#endif
