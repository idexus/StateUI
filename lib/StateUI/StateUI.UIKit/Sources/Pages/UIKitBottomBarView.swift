// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bottom bar over the page's foot: its view as tall as it lays out across the safe area, on the keyboard
/// while one shows (`BottomBarPlace`); what scrolls under it shows at its edge as UIKit draws the edge it asks for.
/// Design: docs/design/host/layout.md#a-bar-at-the-foot
@MainActor
final class UIKitBottomBarView: UIKitLayoutView {
    /// Shows `bar` - the visible page's bottom bar - in place of what it showed; nil for none.
    func show(_ bar: MountedElement?) {
        setItems(bar?.uiKit.layoutItem.map { [$0] } ?? [])
    }

    /// Where the bar stands at the foot of `safe` in `whole`, measured again - what it shows may have changed its
    /// size; nil where it shows nothing.
    func place(safe: Rect, whole: Rect) -> BottomBarPlace? {
        forgetMeasurements()
        guard let item = items.first, item.isShown else { return nil }
        return BottomBarPlace(height: measuredSize(width: safe.width).height, safe: safe, whole: whole)
    }

    /// Stands the bar at `place` and has `scroller` show `edge` under it; nowhere for no place.
    func stand(at place: BottomBarPlace?, edge: ScrollEdge, scroller: UIScrollView?) {
        guard let bar = place?.bar else { return frame = .zero }
        frame = CGRect(x: bar.x, y: bar.y, width: bar.width, height: bar.height)
        let interaction = interactions.compactMap { $0 as? UIScrollEdgeElementContainerInteraction }.first ?? {
            let made = UIScrollEdgeElementContainerInteraction()
            made.edge = .bottom
            addInteraction(made)
            return made
        }()
        if interaction.scrollView !== scroller { interaction.scrollView = scroller }
        guard let effect = scroller?.bottomEdgeEffect else { return }
        let style: UIScrollEdgeEffect.Style = edge == .hard ? .hard : .automatic
        if effect.style != style { effect.style = style }
        if effect.isHidden != (edge == .none) { effect.isHidden = edge == .none }
    }

    /// The edge the scroller under the bar shows, read off the scroller: what a test reads.
    var shownEdge: ScrollEdge? {
        let scroller = interactions.compactMap { ($0 as? UIScrollEdgeElementContainerInteraction)?.scrollView }.first
        guard let effect = scroller?.bottomEdgeEffect else { return nil }
        return effect.isHidden ? ScrollEdge.none : effect.style == .hard ? .hard : .automatic
    }

    override func contentSize(width: Double?) -> LayoutSize {
        SingleChildArithmetic.size(of: items.first, width: width)
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first else { return }
        place(item, at: SingleChildArithmetic.place(of: item, in: bounds, direction: direction))
    }
}
#endif
