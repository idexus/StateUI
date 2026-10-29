// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bottom bar in its room - a window's, a sheet's, a split view's pane: the bar's view at the room's foot over
/// the page, as tall as it lays out across the safe area (`BottomBarPlace`); on the page while nothing stands under
/// it, on a blur with a line along its top, down to the room's edge, while the page's rows pass under it.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
final class AppKitBottomBarView: AppKitSingleChildView {
    /// What the bar stands on while anything stands under it: the material of the window's bars.
    private let ground: NSVisualEffectView = {
        let ground = NSVisualEffectView()
        ground.material = .titlebar
        ground.blendingMode = .withinWindow
        ground.state = .followsWindowActiveState
        ground.isHidden = true
        return ground
    }()

    /// The line along the ground's top, parting the bar from what passes under it.
    private let line: NSBox = {
        let line = NSBox()
        line.boxType = .separator
        line.isHidden = true
        return line
    }()

    /// Where the bar's view stands on its ground.
    private var barRoom = Rect(x: 0, y: 0, width: 0, height: 0)

    /// Shows `bar` - the visible page's bottom bar - in place of what it showed; nil for none.
    func show(_ bar: MountedElement?) {
        setItem(bar?.appKit.layoutItem)
    }

    override func setItem(_ item: AppKitLayoutItem?) {
        super.setItem(item)
        if ground.superview !== self { addSubview(ground, positioned: .below, relativeTo: nil) }
        if line.superview !== self { addSubview(line, positioned: .above, relativeTo: ground) }
    }

    /// Where the bar stands at the foot of `safe` in `whole`, as tall as it lays out across it; nil where it shows
    /// nothing.
    func place(safe: Rect, whole: Rect) -> BottomBarPlace? {
        guard let item, item.isShown else { return nil }
        return BottomBarPlace(height: Double(fittingContentSize(width: safe.width).height), safe: safe, whole: whole)
    }

    /// Stands the bar at `place` - its ground across the room's foot, its view in the bar's place on it - and
    /// follows what of `page` stands under it: its content, `scroller`'s rows as they move. Nowhere for no place.
    func stand(at place: BottomBarPlace?, over page: MountedElement?, scroller: AppKitScrollView?) {
        guard let place else { return frame = .zero }
        frame = NSRect(placed: place.ground)
        barRoom = Rect(x: place.bar.x - place.ground.x, y: 0, width: place.bar.width, height: place.bar.height)
        needsLayout = true
        let runsUnder = page.map {
            SafeAreaArithmetic.under($0.contentIgnoresSafeArea, direction: $0.layoutDirection).bottom
        } ?? false
        let follow: () -> Void = { [weak self, weak scroller] in
            self?.standsOnGround(BottomBarPlace.covers(contentRunsUnder: runsUnder, scroller: scroller?.standing))
        }
        scroller?.standingChanged = follow
        follow()
    }

    /// Shows the ground and its line while anything stands under the bar.
    private func standsOnGround(_ covers: Bool) {
        ground.isHidden = !covers
        line.isHidden = !covers
    }

    override var childRoom: Rect { barRoom }

    override func layout() {
        ground.frame = bounds
        line.frame = NSRect(x: 0, y: 0, width: bounds.width, height: 1)
        super.layout()
    }
}

#endif
