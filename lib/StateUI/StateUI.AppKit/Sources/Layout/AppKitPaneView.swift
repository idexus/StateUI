// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One pane of a split view, a room: its column's content stands against the safe area as a window's page does,
/// the bars' brush paints the part they cover, and a sidebar's pane stands on its split view's material.
/// Design: docs/design/platforms/appkit/views.md#a-sidebars-material
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

    /// The column the pane holds, whose visible page says which edges its content runs under.
    weak var column: MountedElement? {
        didSet { needsLayout = true }
    }

    /// The column's visible page's bottom bar, over the pane's foot.
    private let bottomBar = AppKitBottomBarView()

    /// The band under the toolbar showing its hard edge while the column's rows pass under it.
    private let topEdge = AppKitTopEdgeView()

    /// Shows the column's visible page's bottom bar and its bar at its foot, or takes them away where it declares
    /// neither.
    func showBottomBar() {
        bottomBar.show(column?.visiblePage)
        if !bottomBar.showsAnything {
            bottomBar.removeFromSuperview()
        } else if bottomBar.superview !== self {
            addSubview(bottomBar, positioned: .above, relativeTo: nil)
        }
        needsLayout = true
    }

    override func setItem(_ item: AppKitLayoutItem?) {
        super.setItem(item)
        if bottomBar.showsAnything, bottomBar.superview !== self { addSubview(bottomBar, positioned: .above, relativeTo: nil) }
    }

    /// Where the bottom bar stands at the pane's foot; nil where it shows none.
    private var bottomBarPlace: BottomBarPlace? {
        bottomBar.superview === self ? bottomBar.place(safe: safeAreaRect.placed, whole: bounds.placed) : nil
    }

    /// The room the column's content stands in against the pane's safe area, its bottom bar standing over its foot.
    override var childRoom: Rect {
        let page = column?.visiblePage
        return SafeAreaArithmetic.room(
            safe: bottomBarPlace?.safe ?? safeAreaRect.placed, whole: bounds.placed,
            edges: page?.contentIgnoresSafeArea ?? .none, direction: page?.layoutDirection ?? .leftToRight)
    }

    override func layout() {
        super.layout()
        let place = bottomBarPlace
        let scroller = column?.visiblePage?.pageScroller?.appKit.view as? AppKitPageScroller
        scroller?.keepClear(SafeAreaArithmetic.clearance(room: childRoom, safe: place?.safe ?? safeAreaRect.placed))
        bottomBar.stand(at: place, over: column?.visiblePage, scroller: scroller)
        if topEdge.superview !== self { addSubview(topEdge, positioned: .above, relativeTo: item?.view) }
        topEdge.stand(
            in: Rect(x: 0, y: 0, width: bounds.width, height: max(0, safeAreaRect.minY)), over: column?.visiblePage,
            scroller: scroller)
        scroller?.standingChanged = { [weak self] in
            self?.bottomBar.follow()
            self?.topEdge.follow()
        }
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
