// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page's bottom bar over the page's foot: its view as tall as it lays out across the safe area, on the keyboard
/// while one shows (`BottomBarPlace`), a scroller under it fading under the bar as under the platform's own.
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

    /// The scroller the page shows under the bar, which fades under it as under a bar of the platform's.
    func standOver(_ scroller: UIScrollView?) {
        guard #available(iOS 26.0, *) else { return }
        let edge = interactions.compactMap { $0 as? UIScrollEdgeElementContainerInteraction }.first ?? {
            let made = UIScrollEdgeElementContainerInteraction()
            made.edge = .bottom
            addInteraction(made)
            return made
        }()
        if edge.scrollView !== scroller { edge.scrollView = scroller }
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
