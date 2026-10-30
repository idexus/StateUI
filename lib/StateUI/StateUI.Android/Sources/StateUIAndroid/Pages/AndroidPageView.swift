// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page: its content in the room the safe area gives it - clear of what stands over the page, or under it where
/// the content says so - its scroller keeping clear what it reaches under (`SafeAreaArithmetic`); its bottom bar at
/// its foot above its bar at its foot, beside the content as Android's bars stand (`BottomBarPlace`).
/// Design: docs/design/platforms/android/pages.md#the-safe-area
@MainActor
final class AndroidPageView: AndroidSingleChildView {
    private weak var page: MountedElement?

    /// The page's bottom bar, whose values the page reads again each time it lays out: it stands in a slot, which no
    /// layout arranges.
    private weak var bar: MountedElement?

    /// The bottom bar's view, held after the content's.
    private var barView: AndroidView?

    /// The line along the bar's top while rows go on past it - its hard edge, which Android draws for none.
    private let line = AndroidSeparatorView()

    /// The edge the bar shows while rows go on past it.
    private(set) var edge = ScrollEdge.automatic

    /// The page's bar at its foot, Android's toolbar holding its actions; nil while it holds none.
    private(set) var toolbar: AndroidBarView?

    init(page: MountedElement) {
        self.page = page
        super.init()
    }

    /// Shows `bar` - the page's bottom bar - at its foot, with `edge` while rows go on past it, above the bar at its
    /// foot showing `actions`; nil for none. The bar at the foot, where one shows.
    func showBottomBar(_ bar: MountedElement?, edge: ScrollEdge, toolbar actions: AndroidBarView.Content?) -> AndroidBarView? {
        self.bar = bar
        self.edge = edge
        let view = bar?.android.layoutItem?.view
        let made = actions.map { _ in toolbar ?? AndroidBarView() }
        defer { requestLayout() }
        if let made, let actions { made.show(actions) }
        guard view !== barView || made !== toolbar else { return made }
        if made == nil { toolbar?.detach() }
        (barView, toolbar) = (view, made)
        holdChildren()
        return made
    }

    override func detach() {
        super.detach()
        toolbar?.detach()
    }

    override func heldViews() -> [AndroidView] {
        super.heldViews() + (barView.map { [$0] } ?? []) + (toolbar.map { [$0] } ?? [])
            + (barView != nil || toolbar != nil ? [line] : [])
    }

    override func arrange(in bounds: Rect) {
        guard let item = items.first, item.isShown else { return }

        let safe = Rect(
            x: bounds.x + roomInsets.left, y: bounds.y + roomInsets.top,
            width: max(0, bounds.width - roomInsets.left - roomInsets.right),
            height: max(0, bounds.height - roomInsets.top - roomInsets.bottom))
        let barItem = bar?.android.layoutItem.flatMap { $0.isShown ? $0 : nil }
        let viewHeight = barItem.map { SingleChildArithmetic.size(of: $0, width: safe.width).height } ?? 0
        let toolbarHeight = toolbar?.height(width: bounds.width) ?? 0
        let place = barItem != nil || toolbar != nil
            ? BottomBarPlace(height: viewHeight + toolbarHeight, safe: safe, whole: bounds) : nil
        // The bar stands beside the content, as the bar at the top does: the content's room ends above it.
        let (whole, clear) = place.map { ($0.above, $0.safe) } ?? (bounds, safe)
        let room = SafeAreaArithmetic.room(
            safe: clear, whole: whole, edges: page?.contentIgnoresSafeArea ?? .none,
            direction: page?.layoutDirection ?? direction)
        item.view.layout(SingleChildArithmetic.place(of: item, in: room, direction: direction))
        if let place {
            let viewRoom = Rect(x: place.bar.x, y: place.bar.y, width: place.bar.width, height: viewHeight)
            if let barItem { barItem.view.layout(SingleChildArithmetic.place(of: barItem, in: viewRoom, direction: direction)) }
            toolbar?.layout(Rect(x: bounds.x, y: place.bar.y + viewHeight, width: bounds.width, height: toolbarHeight))
            line.layout(Rect(x: bounds.x, y: place.bar.y, width: bounds.width, height: 1))
        }
        let scroller = page?.pageScroller?.android.view as? AndroidScrollView
        scroller?.keepClear(SafeAreaArithmetic.clearance(room: room, safe: clear))
        let follow: () -> Void = { [weak self, weak scroller] in
            guard let self else { return }
            line.setShown(edge != .none && BottomBarPlace.continues(scroller: scroller?.standing))
        }
        scroller?.standingChanged = follow
        follow()
    }
}
