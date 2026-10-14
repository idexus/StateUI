// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A TabView: the chosen tab's page, under a row of tabs - WinUI's `SelectorBar` - of its own, or under the
/// window's where its tabs are the window's.
/// Design: docs/design/platforms/winui/pages.md#tabs
@MainActor
final class WinUITabView: WinUILayoutView {
    /// Which tab the view shows, by the host layer's rule.
    private(set) var choice = TabChoice()

    /// What the view does when the user chooses a tab, handed the one it showed and the one it shows.
    var onSelection: ((_ previous: Int, _ selected: Int) -> Void)?

    /// Whether its tabs stand in the window's row, beneath the window's chrome, rather than in a row of its own.
    var tabsShownByWindow = false {
        didSet {
            guard tabsShownByWindow != oldValue else { return }
            holdChildren()
            invalidateMeasurements()
        }
    }

    /// The tabs, as the tree says them.
    private(set) var tabs: [WinUITab] = []

    /// The row of tabs of its own, shown where the window shows none.
    let row = WinUITabsView()

    /// Whether its tabs stand in its own row: where the window shows none, and under its heading where it is headed -
    /// the title names what the tabs are tabs of, over them.
    /// Design: docs/design/platforms/winui/pages.md#a-pages-heading
    var showsOwnRow: Bool { !tabsShownByWindow || heading != nil }

    override init() {
        super.init()
        row.onChosen = { [weak self] index in self?.selectByUser(index) }
    }

    override func heldViews() -> [WinUIView] {
        (showsOwnRow ? [row] : []) + (selectedItem.map { [$0.view] } ?? [])
    }

    /// The tab the view shows, as an index into its tabs; -1 for none.
    var shownIndex: Int { choice.shown(among: tabs.count) ?? -1 }

    /// Shows the tabs and the one the tree asks for, where the user has not chosen another since.
    func show(_ tabs: [WinUITab], requested: Int?) {
        if choice.request(requested) {
            holdChildren()
            invalidateMeasurements()
        }
        self.tabs = tabs
        row.show(tabs, chosen: shownIndex)
    }

    /// The user chose a tab: it shows, and the view says so.
    func selectByUser(_ index: Int) {
        guard let previous = choice.choose(index, of: items.count) else { return }

        row.show(tabs, chosen: index)
        holdChildren()
        invalidateMeasurements()
        onSelection?(previous, index)
    }

    private var selectedItem: WinUILayoutItem? {
        choice.shown(among: items.count).map { items[$0] }
    }

    override func contentSize(width: Double?) -> LayoutSize {
        let tabbed = RowEdge.size(
            page: SingleChildArithmetic.size(of: selectedItem, width: width),
            row: rowHeight(width: width))
        return heading.map { RowEdge.size(page: tabbed, row: $0.height(width: width)) } ?? tabbed
    }

    override func arrange(in bounds: Rect) {
        let headed = heading?.place(in: bounds) ?? bounds
        let (rowRoom, room) = RowEdge.top.split(headed, row: rowHeight(width: headed.width))
        if showsOwnRow { row.layout(rowRoom) }
        guard let page = selectedItem else { return }

        page.view.layout(SingleChildArithmetic.place(of: page, in: room, direction: direction))
    }

    /// The own row's height for `width` DIPs; none where the window shows the tabs.
    private func rowHeight(width: Double?) -> Double {
        showsOwnRow ? row.measure(width: width, height: nil).height : 0
    }

    override func detach() {
        super.detach()
        onSelection = nil
        row.detach()
    }
}
