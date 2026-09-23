// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// The stable native root of one StateUI window. Pages and overlays occupy
/// AppKit's safe content rectangle, leaving native title and toolbar areas to
/// the window; a split page spans the whole window, under them, and keeps its
/// panes' pages out of them itself. A window overlay is a slot, not a second
/// page: it is composed above the page and transparent to input wherever its
/// child has no hit target.
///
/// A room: a change inside the page is laid out by the page, and the window is
/// not asked.
@MainActor
final class AppKitWindowContentView: NSView, AppKitRoom {
    private weak var page: NSView?
    private var pageSpansTitleBar = false
    private let overlaySurface = AppKitOverlaySurfaceView()

    /// The window's own material, under the page, while the window lets the
    /// desktop show through it.
    private var material: NSVisualEffectView?

    /// What lies over the whole material, in `materialTint`.
    private var materialTintView: NSView?

    /// Whether the desktop shows through the window: its material lies under
    /// the page, wherever the page leaves it uncovered or paints a colour it
    /// shows through - in `materialTint`, where one is written.
    var isTranslucent = false {
        didSet {
            guard isTranslucent != oldValue else { return }

            if isTranslucent {
                let material = NSVisualEffectView()
                material.material = .underWindowBackground
                material.blendingMode = .behindWindow
                material.state = .followsWindowActiveState
                let tint = NSView()
                tint.wantsLayer = true
                material.addSubview(tint)
                addSubview(material, positioned: .below, relativeTo: nil)
                self.material = material
                materialTintView = tint
            } else {
                material?.removeFromSuperview()
                material = nil
                materialTintView = nil
            }
            needsLayout = true
        }
    }

    var materialForTesting: NSVisualEffectView? { material }
    /// The colour the window's bars are written in, over the material of a
    /// translucent window: the band above the page, the margin around a
    /// floating sidebar and what its glass shows all wear it, the desktop
    /// through it. Nil leaves the material the system's.
    var materialTint: NSColor? {
        didSet { if materialTint != oldValue { needsLayout = true } }
    }

    var materialTintForTesting: NSView? { materialTintView }

    /// The colour the window's bars are written in, painted over `barBand`.
    /// Nil leaves the title bar and toolbar the system's material.
    var barColor: NSColor? {
        didSet { if barColor != oldValue { needsDisplay = true; needsLayout = true } }
    }

    /// The part of the window the title bar and toolbar cover.
    var barBand: NSRect {
        NSRect(x: 0, y: 0, width: bounds.width, height: max(0, safeAreaRect.minY))
    }

    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let barColor else { return }
        barColor.setFill()
        barBand.fill()
    }

    func set(page: NSView?, overlay: AppKitLayoutItem?, spansTitleBar: Bool = false) {
        if pageSpansTitleBar != spansTitleBar {
            pageSpansTitleBar = spansTitleBar
            needsLayout = true
        }
        if self.page !== page {
            self.page?.removeFromSuperview()
            self.page = page
            if let page {
                page.translatesAutoresizingMaskIntoConstraints = true
                addSubview(page, positioned: material == nil ? .below : .above, relativeTo: material)
            }
        }

        overlaySurface.setItem(overlay)
        if overlay == nil {
            overlaySurface.removeFromSuperview()
        } else if overlaySurface.superview !== self {
            addSubview(overlaySurface, positioned: .above, relativeTo: page)
        }

        invalidateIntrinsicContentSize()
        needsLayout = true
    }

    override var intrinsicContentSize: NSSize {
        page?.fittingSize ?? .zero
    }

    override func layout() {
        super.layout()
        if let material {
            material.frame = bounds
            materialTintView?.frame = material.bounds
            materialTintView?.layer?.backgroundColor = materialTint?.cgColor
            materialTintView?.isHidden = materialTint == nil
        }
        page?.frame = pageSpansTitleBar ? bounds : safeAreaRect
        overlaySurface.frame = safeAreaRect
        overlaySurface.layoutSubtreeIfNeeded()
        if barColor != nil { needsDisplay = true }
    }
}

/// Full-window hit-test surface whose empty area deliberately falls through
/// to the page below it.
@MainActor
private final class AppKitOverlaySurfaceView: AppKitSingleChildView {
    override func hitTest(_ point: NSPoint) -> NSView? {
        let target = super.hitTest(point)
        return target === self ? nil : target
    }
}

#endif
