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
    private let bottomBar = AppKitBottomBarView()

    /// The window's own material, under the page, while the window lets the
    /// desktop show through it.
    private var material: AppKitMaterialView?

    /// The band the title bar and toolbar cover, painted in `barBrush` - over
    /// the material, where the window has one.
    private lazy var band: AppKitBandView = {
        let band = AppKitBandView()
        addSubview(band, positioned: .below, relativeTo: nil)
        return band
    }()

    /// What takes a key equivalent no view of the window took - a bar's item stating it.
    var unclaimedKey: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        super.performKeyEquivalent(with: event) || unclaimedKey?(event) == true
    }

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

    /// The material the desktop shows through the window in: it lies under the page and the bars' band,
    /// wherever they leave it uncovered or paint a color it shows through; nil for an opaque window.
    var backdrop: Blur.Thickness? {
        didSet {
            guard backdrop != oldValue else { return }
            if let backdrop {
                let material = self.material ?? {
                    let made = AppKitMaterialView(backdrop, behindWindow: true)
                    addSubview(made, positioned: .below, relativeTo: nil)
                    self.material = made
                    return made
                }()
                material.material = AppKitMaterialView.role(backdrop)
            } else {
                material?.removeFromSuperview()
                material = nil
            }
            needsLayout = true
        }
    }

    var materialForTesting: NSVisualEffectView? { material }

    /// The window's background over its material, where the desktop shows
    /// through the window: a color with an alpha tints the material and lets
    /// it show. Nil leaves the material the system's.
    var materialTint: NSColor? {
        didSet { if materialTint != oldValue { needsLayout = true } }
    }

    var materialTintForTesting: NSView? { material?.wash }

    /// What the window's bars are painted with - a color or a gradient - over `barBand`.
    /// Nothing leaves the title bar and toolbar the system's material.
    var barBrush = AppKitBrush() {
        didSet { if barBrush != oldValue { needsLayout = true } }
    }

    /// The part of the window the title bar and toolbar cover.
    var barBand: NSRect {
        NSRect(x: 0, y: 0, width: bounds.width, height: max(0, safeAreaRect.minY))
    }

    override var isFlipped: Bool { true }

    /// The page the user sees on the arrangement this view shows - the room its content stands in against the safe
    /// area, and its scroller, are its own.
    weak var visiblePage: MountedElement? {
        didSet { needsLayout = true }
    }

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

        if bottomBar.superview === self, let page { addSubview(bottomBar, positioned: .above, relativeTo: page) }
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

    /// Lets what reads a frame say where it stands, once the window is laid out and before it draws; whether
    /// anything did.
    var reportsLaidOut: () -> Bool = { false }

    override func layout() {
        super.layout()
        if let material {
            material.frame = bounds
            material.wash.layer?.backgroundColor = materialTint?.cgColor
            material.wash.isHidden = materialTint == nil
        }
        band.frame = barBand
        band.brush = barBrush
        if pageSpansTitleBar {
            page?.frame = bounds
        } else {
            layPage()
        }
        overlaySurface.frame = safeAreaRect
        overlaySurface.layoutSubtreeIfNeeded()
        layOutReporting(page)
    }
}

extension AppKitWindowContentView {
    /// Shows `page`'s bottom bar and its bar at its foot over the page's foot; nothing for no page.
    func showBottomBar(of page: MountedElement?) {
        bottomBar.show(page)
        if !bottomBar.showsAnything {
            bottomBar.removeFromSuperview()
        } else if bottomBar.superview !== self {
            addSubview(bottomBar, positioned: .below, relativeTo: overlaySurface.superview === self ? overlaySurface : nil)
        }
        needsLayout = true
    }

    /// Lays the page in the room its content stands in - clear of the toolbar and the bottom bar, or under them where
    /// it says so - and has its scroller keep clear what it reaches under (`SafeAreaArithmetic`).
    /// Design: docs/design/host/layout.md#the-safe-area
    private func layPage() {
        let whole = Rect(x: 0, y: 0, width: bounds.width, height: bounds.height)
        let place = bottomBar.superview === self ? bottomBar.place(safe: safeAreaRect.placed, whole: whole) : nil
        let safe = place?.safe ?? safeAreaRect.placed
        let room = SafeAreaArithmetic.room(
            safe: safe, whole: whole,
            edges: visiblePage?.contentIgnoresSafeArea ?? .none, direction: visiblePage?.layoutDirection ?? .leftToRight)
        page?.frame = NSRect(x: room.x, y: room.y, width: room.width, height: room.height)
        let scroller = visiblePage?.pageScroller?.appKit.view as? AppKitPageScroller
        scroller?.keepClear(SafeAreaArithmetic.clearance(room: room, safe: safe))
        bottomBar.stand(at: place, over: visiblePage, scroller: scroller)
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
