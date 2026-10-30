// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bottom bar in its room - a window's, a sheet's, a split view's pane: the bar's view at the room's foot over
/// the page, above the page's bar at its foot (`.toolbar(.bottom)`), the two as tall as they lay out across the safe
/// area (`BottomBarPlace`); on the page while nothing stands under them, and at its edge (`ScrollEdge`) while the
/// page's rows pass under them - AppKit drawing none for a view of its own, a blur in the page's hue down to the
/// room's edge, a line along its top where the edge is hard.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
final class AppKitBottomBarView: AppKitSingleChildView {
    /// The blur under the edge, in the page's own hue (`bottomBarTint`).
    private let ground: AppKitMaterialView = {
        let ground = AppKitMaterialView(BottomBarPlace.blur, behindWindow: false)
        ground.isHidden = true
        return ground
    }()

    /// The line along the hard edge.
    private let line: NSBox = {
        let line = NSBox()
        line.boxType = .separator
        line.isHidden = true
        return line
    }()

    /// The page's bar at its foot, under the bar's view.
    let toolbar = AppKitBottomToolbar()

    /// The page whose bars it shows.
    private(set) weak var page: MountedElement?

    /// The edge the bar shows while rows pass under it.
    private(set) var edge = ScrollEdge.automatic

    /// Where the bar's view stands on its ground.
    private var barRoom = Rect(x: 0, y: 0, width: 0, height: 0)

    /// Shows `page`'s bottom bar and its bar at its foot in place of what it showed; nothing for none.
    func show(_ page: MountedElement?) {
        self.page = page
        setItem(page?.chromeBottomBar?.appKit.layoutItem)
        toolbar.show(page?.chromeBottomActions ?? ChromeActions())
    }

    /// Whether it shows anything: a view, or a bar at the foot.
    var showsAnything: Bool {
        item?.isShown == true || toolbar.holdsItems
    }

    override func setItem(_ item: AppKitLayoutItem?) {
        super.setItem(item)
        if ground.superview !== self { addSubview(ground, positioned: .below, relativeTo: nil) }
        if line.superview !== self { addSubview(line, positioned: .above, relativeTo: ground) }
        if toolbar.superview !== self { addSubview(toolbar) }
    }

    /// How tall the bar at the foot stands; nought for none.
    private var toolbarHeight: Double {
        toolbar.holdsItems ? AppKitBottomToolbar.height : 0
    }

    /// Where the bar stands at the foot of `safe` in `whole`, its view as tall as it lays out across it above the bar
    /// at the foot; nil where it shows nothing.
    func place(safe: Rect, whole: Rect) -> BottomBarPlace? {
        let view = item?.isShown == true ? Double(fittingContentSize(width: safe.width).height) : 0
        guard view + toolbarHeight > 0 else { return nil }
        return BottomBarPlace(height: view + toolbarHeight, safe: safe, whole: whole)
    }

    /// Stands the bar at `place` - across the room's foot, its view in the bar's place above the bar at the foot - and
    /// follows what of `page` stands under it: its content, `scroller`'s rows as they move. Nowhere for no place.
    func stand(at place: BottomBarPlace?, over page: MountedElement?, scroller: AppKitPageScroller?) {
        guard let place else { return frame = .zero }
        edge = page?.chromeBottomBarEdge ?? .automatic
        let color = page?.bottomBarTint.flatMap(paintedColor) ?? window?.backgroundColor
        ground.wash.wantsLayer = true
        ground.wash.layer?.backgroundColor = color.map { $0.withAlphaComponent($0.alphaComponent * BottomBarPlace.tint) }?
            .cgColor
        ground.wash.isHidden = color == nil
        frame = NSRect(placed: place.ground)
        let view = place.bar.height - toolbarHeight
        barRoom = Rect(x: place.bar.x - place.ground.x, y: 0, width: place.bar.width, height: view)
        toolbar.frame = NSRect(x: barRoom.x, y: view, width: place.bar.width, height: toolbarHeight)
        needsLayout = true
        let runsUnder = page.map {
            SafeAreaArithmetic.under($0.contentIgnoresSafeArea, direction: $0.layoutDirection).bottom
        } ?? false
        let follow: () -> Void = { [weak self, weak scroller] in
            guard let self else { return }
            let covered = BottomBarPlace.covers(contentRunsUnder: runsUnder, scroller: scroller?.standing)
            ground.isHidden = !covered || edge == .none
            line.isHidden = ground.isHidden || edge != .hard
        }
        scroller?.standingChanged = follow
        follow()
    }

    override var childRoom: Rect { barRoom }

    override func layout() {
        ground.frame = bounds
        line.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 1)
        super.layout()
    }
}

#endif
