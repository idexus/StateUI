// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A page, or a container like it: its one child in its room - under its title where the window heads the page.
@MainActor
class WinUISingleChildView: WinUILayoutView {
    /// A page's bottom bar beneath its content, which ends above it - bars stand beside the page on Windows; nil for
    /// none.
    private var bottomBar: WinUILayoutItem?

    /// The line along the bar's top while rows go on past it - its hard edge, which WinUI draws for none.
    private lazy var line = WinUIStackPartView.separator()

    /// The edge the bar shows while rows go on past it.
    private(set) var edge = ScrollEdge.automatic

    /// The page's scroller, whose rows going on the line follows.
    private weak var scroller: WinUIPageScroller?

    /// The page's bar at its foot, beneath its bottom bar; nil while it holds no action.
    private(set) var toolbar: WinUIFootBarView?

    /// Shows `bar` - the page's bottom bar - beneath its content, with `edge` while `scroller`'s rows go on past it;
    /// nil for none.
    /// Design: docs/design/host/layout.md#a-bar-at-the-foot
    func showBottomBar(_ bar: WinUILayoutItem?, edge: ScrollEdge, scroller: WinUIPageScroller?) {
        let held = bar?.view !== bottomBar?.view
        (bottomBar, self.edge, self.scroller) = (bar, edge, scroller)
        scroller?.standingChanged = { [weak self] in self?.showLine() }
        showLine()
        guard held else { return }
        holdChildren()
        invalidateMeasurements()
    }

    /// Shows `actions` on the bar at the page's foot, beneath its bottom bar; none takes the bar away.
    func showToolbar(_ actions: ChromeActions) {
        let made = actions.isEmpty ? nil : toolbar ?? WinUIFootBarView()
        made?.show(actions)
        guard made !== toolbar else { return }
        toolbar?.detach()
        toolbar = made
        holdChildren()
        invalidateMeasurements()
    }

    /// Shows the line while the bar shows an edge and rows go on past it.
    private func showLine() {
        line.setShown(
            (bottomBar != nil || toolbar != nil) && edge != .none && BottomBarPlace.continues(scroller: scroller?.standing))
    }

    override func heldViews() -> [WinUIView] {
        super.heldViews() + (bottomBar.map { [$0.view] } ?? []) + (toolbar.map { [$0] } ?? [])
            + (bottomBar != nil || toolbar != nil ? [line] : [])
    }

    override func detach() {
        super.detach()
        toolbar?.detach()
    }

    /// How tall the bottom bar and the bar at the foot stand at `width`; nought for neither.
    private func footHeight(width: Double?) -> Double {
        (shownBar.map { SingleChildArithmetic.size(of: $0, width: width).height } ?? 0)
            + (toolbar?.measured(width: width).height ?? 0)
    }

    override func contentSize(width: Double?) -> LayoutSize {
        var child = SingleChildArithmetic.size(of: items.first, width: width)
        let foot = footHeight(width: width)
        if foot > 0 { child = RowEdge.size(page: child, row: foot) }
        guard let heading else { return child }
        return RowEdge.size(page: child, row: heading.height(width: width))
    }

    override func arrange(in bounds: Rect) {
        var room = heading?.place(in: bounds) ?? bounds
        // Measured at the width the measure offered, which WinUI answers inside an arrangement from what it kept.
        let foot = footHeight(width: room.width)
        if foot > 0 {
            let place = BottomBarPlace(height: foot, safe: room, whole: room)
            let barHeight = shownBar.map { SingleChildArithmetic.size(of: $0, width: room.width).height } ?? 0
            if let bar = shownBar {
                let barRoom = Rect(x: place.bar.x, y: place.bar.y, width: place.bar.width, height: barHeight)
                bar.view.layout(SingleChildArithmetic.place(of: bar, in: barRoom, direction: direction))
            }
            toolbar?.layout(Rect(x: room.x, y: place.bar.y + barHeight, width: room.width, height: foot - barHeight))
            line.layout(Rect(x: room.x, y: place.bar.y, width: room.width, height: 1))
            room = place.above
        }
        guard let item = items.first, item.isShown else { return }

        item.view.layout(SingleChildArithmetic.place(of: item, in: room, direction: direction))
    }

    /// The bottom bar while it shows.
    private var shownBar: WinUILayoutItem? {
        bottomBar.flatMap { $0.isShown ? $0 : nil }
    }
}
