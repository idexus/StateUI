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

    /// Shows `bar` - the page's bottom bar - beneath its content; nil for none.
    /// Design: docs/design/host/layout.md#a-bar-at-the-foot
    func showBottomBar(_ bar: WinUILayoutItem?) {
        let held = bar?.view !== bottomBar?.view
        bottomBar = bar
        guard held else { return }
        holdChildren()
        invalidateMeasurements()
    }

    override func heldViews() -> [WinUIView] {
        super.heldViews() + (bottomBar.map { [$0.view] } ?? [])
    }

    override func contentSize(width: Double?) -> LayoutSize {
        var child = SingleChildArithmetic.size(of: items.first, width: width)
        if let bar = shownBar { child = RowEdge.size(page: child, row: SingleChildArithmetic.size(of: bar, width: width).height) }
        guard let heading else { return child }
        return RowEdge.size(page: child, row: heading.height(width: width))
    }

    override func arrange(in bounds: Rect) {
        var room = heading?.place(in: bounds) ?? bounds
        if let bar = shownBar {
            // Measured at the width the measure offered, which WinUI answers inside an arrangement from what it kept.
            let place = BottomBarPlace(
                height: SingleChildArithmetic.size(of: bar, width: room.width).height, safe: room, whole: room)
            bar.view.layout(SingleChildArithmetic.place(of: bar, in: place.bar, direction: direction))
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
