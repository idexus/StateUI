// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

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

    /// The band the title bar and toolbar cover, painted in `barColor` - over
    /// the material, where the window has one.
    private lazy var band: NSView = {
        let band = NSView()
        band.wantsLayer = true
        band.isHidden = true
        addSubview(band, positioned: .below, relativeTo: nil)
        return band
    }()

    /// The window's drags between views, where this view is the window's root.
    /// Design: docs/design/platforms/appkit/input.md#a-drag-between-views
    var drops: AppKitDrops? {
        didSet { drops == nil ? unregisterDraggedTypes() : registerForDraggedTypes([.string, .fileURL]) }
    }

    override func draggingEntered(_ sender: any NSDraggingInfo) -> NSDragOperation {
        drops?.entered(at: sender.draggingLocation, carrying: sender.carried, in: self) ?? []
    }

    override func draggingUpdated(_ sender: any NSDraggingInfo) -> NSDragOperation {
        drops?.moved(to: sender.draggingLocation, carrying: sender.carried, in: self) ?? []
    }

    override func draggingExited(_ sender: (any NSDraggingInfo)?) {
        drops?.exited()
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        drops?.dropped(sender.carried) ?? false
    }

    /// Whether the desktop shows through the window: its material lies under
    /// the page and the bars' band, wherever they leave it uncovered or paint a
    /// colour it shows through.
    var isTranslucent = false {
        didSet {
            guard isTranslucent != oldValue else { return }

            if isTranslucent {
                let material = NSVisualEffectView()
                material.material = .underWindowBackground
                material.blendingMode = .behindWindow
                material.state = .followsWindowActiveState
                addSubview(material, positioned: .below, relativeTo: nil)
                self.material = material
            } else {
                material?.removeFromSuperview()
                material = nil
            }
            needsLayout = true
        }
    }

    var materialForTesting: NSVisualEffectView? { material }

    /// The colour the window's bars are written in, painted over `barBand`.
    /// Nil leaves the title bar and toolbar the system's material.
    var barColor: NSColor? {
        didSet { if barColor != oldValue { needsLayout = true } }
    }

    /// The part of the window the title bar and toolbar cover.
    var barBand: NSRect {
        NSRect(x: 0, y: 0, width: bounds.width, height: max(0, safeAreaRect.minY))
    }

    override var isFlipped: Bool { true }

    func set(page: NSView?, overlays: [AppKitLayoutItem], spansTitleBar: Bool = false) {
        if pageSpansTitleBar != spansTitleBar {
            pageSpansTitleBar = spansTitleBar
            needsLayout = true
        }
        if self.page !== page {
            self.page?.removeFromSuperview()
            self.page = page
            if let page {
                page.translatesAutoresizingMaskIntoConstraints = true
                addSubview(page, positioned: .above, relativeTo: band)
            }
        }

        overlaySurface.setItems(overlays)
        if overlays.isEmpty {
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
        material?.frame = bounds
        band.frame = barBand
        band.layer?.backgroundColor = barColor?.cgColor
        band.isHidden = barColor == nil
        page?.frame = pageSpansTitleBar ? bounds : safeAreaRect
        overlaySurface.frame = safeAreaRect
        overlaySurface.layoutSubtreeIfNeeded()
    }
}

/// The window's overlays, one layer over another, each over the whole area; a click beside what they hold goes on
/// to the page under them.
@MainActor
private final class AppKitOverlaySurfaceView: NSView {
    private var layers: [AppKitSingleChildView] = []

    override var isFlipped: Bool { true }

    /// Lays `items`, the first lowest, each in a layer of its own.
    func setItems(_ items: [AppKitLayoutItem]) {
        while layers.count > items.count {
            let leaving = layers.removeLast()
            leaving.setItem(nil)
            leaving.removeFromSuperview()
        }
        while layers.count < items.count {
            let layer = AppKitSingleChildView()
            addSubview(layer)
            layers.append(layer)
        }
        for (layer, item) in zip(layers, items) { layer.setItem(item) }
        needsLayout = true
    }

    override func layout() {
        super.layout()
        for layer in layers {
            layer.frame = bounds
            layer.layoutSubtreeIfNeeded()
        }
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        let target = super.hitTest(point)
        return target === self || layers.contains { $0 === target } ? nil : target
    }
}

#endif
