// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page: its content in the room the safe area gives it - clear of what stands over the page, or under it where
/// the content says so - its scroller keeping clear what it reaches under (`SafeAreaArithmetic`); its bottom bar at
/// its foot, beside the content as Android's bars stand (`BottomBarPlace`).
/// Design: docs/design/platforms/android/pages.md#the-safe-area
@MainActor
final class AndroidPageView: AndroidSingleChildView {
    private weak var page: MountedElement?

    /// The page's bottom bar, whose values the page reads again each time it lays out: it stands in a slot, which no
    /// layout arranges.
    private weak var bar: MountedElement?

    /// The bottom bar's view, held after the content's.
    private var barView: AndroidView?

    init(page: MountedElement) {
        self.page = page
        super.init()
    }

    /// Shows `bar` - the page's bottom bar - at its foot; nil for none.
    func showBottomBar(_ bar: MountedElement?) {
        self.bar = bar
        let view = bar?.android.layoutItem?.view
        guard view !== barView else { return }
        barView = view
        holdChildren()
        requestLayout()
    }

    override func heldViews() -> [AndroidView] {
        super.heldViews() + (barView.map { [$0] } ?? [])
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }

        let safe = Rect(
            x: bounds.x + roomInsets.left, y: bounds.y + roomInsets.top,
            width: max(0, bounds.width - roomInsets.left - roomInsets.right),
            height: max(0, bounds.height - roomInsets.top - roomInsets.bottom))
        let barItem = bar?.android.layoutItem.flatMap { $0.isShown ? $0 : nil }
        let place = barItem.map {
            BottomBarPlace(height: SingleChildArithmetic.size(of: $0, width: safe.width).height, safe: safe, whole: bounds)
        }
        // The bar stands beside the content, as the bar at the top does: the content's room ends above it.
        let (whole, clear) = place.map { ($0.above, $0.safe) } ?? (bounds, safe)
        let room = SafeAreaArithmetic.room(
            safe: clear, whole: whole, edges: page?.contentIgnoresSafeArea ?? .none,
            direction: page?.layoutDirection ?? direction)
        item.view.layout(SingleChildArithmetic.place(of: item, in: room, direction: direction))
        if let barItem, let place {
            barItem.view.layout(SingleChildArithmetic.place(of: barItem, in: place.bar, direction: direction))
        }
        (page?.pageScroller?.android.view as? AndroidScrollView)?.keepClear(
            SafeAreaArithmetic.clearance(room: room, safe: clear))
    }
}
