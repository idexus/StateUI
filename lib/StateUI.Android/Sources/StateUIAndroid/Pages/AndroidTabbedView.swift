// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A TabbedView: the chosen tab's page over a row of tabs along the bottom, the host's `StateUITabs`.
/// Design: docs/design/platforms/android/pages.md#tabs
@MainActor
final class AndroidTabbedView: AndroidLayoutView {
    /// One tab as its row shows it.
    struct Tab: Equatable {
        var title: String
        var picture: String?
    }

    /// The row's tabs and colours, as the tree says them.
    struct Row: Equatable {
        var tabs: [Tab] = []
        var background: HostValue?
        var color: HostValue?
        var chosenColor: HostValue?
    }

    /// The tab the user sees; nil until the tree or the user chooses one.
    private(set) var selectedIndex: Int?

    /// What the view does when the user chooses a tab, handed the one it showed and the one it shows.
    var onSelection: ((_ previous: Int, _ selected: Int) -> Void)?

    private let row = AndroidTabsView()
    private var shownRow = Row()
    private var shownChosen = -1

    override init() {
        super.init()
        row.onChosen = { [weak self] index in self?.selectByUser(index) }
    }

    override func heldViews() -> [AndroidView] {
        (selectedItem.map { [$0.view] } ?? []) + [row]
    }

    /// Shows `row` and the tab the tree asks for, where the user has not chosen another since.
    func show(_ row: Row, requested: Int?) {
        if let requested, requested != selectedIndex {
            selectedIndex = requested
            holdChildren()
            invalidateMeasurements()
        }
        let chosen = selectedIndex ?? 0
        guard row != shownRow || chosen != shownChosen else { return }

        shownRow = row
        shownChosen = chosen
        self.row.show(row, chosen: chosen)
    }

    /// The user chose a tab: it shows, and the view says so.
    func selectByUser(_ index: Int) {
        let previous = selectedIndex ?? 0
        guard index != previous, items.indices.contains(index) else { return }

        selectedIndex = index
        shownChosen = index
        holdChildren()
        invalidateMeasurements()
        row.show(shownRow, chosen: index)
        onSelection?(previous, index)
    }

    private var selectedItem: AndroidLayoutItem? {
        guard !items.isEmpty else { return nil }
        return items[min(max(selectedIndex ?? 0, 0), items.count - 1)]
    }

    override func contentSize(width: Double?) -> LayoutSize {
        let page = SingleChildArithmetic.size(of: selectedItem, padding: Insets(0), width: width)
        return LayoutSize(width: page.width, height: page.height + rowHeight(width: width))
    }

    override func arrange(in bounds: Rect) {
        let height = rowHeight(width: bounds.width)
        row.layout(Rect(x: 0, y: bounds.height - height, width: bounds.width, height: height))
        guard let page = selectedItem else { return }

        let room = Rect(x: 0, y: 0, width: bounds.width, height: max(0, bounds.height - height))
        page.view.layout(SingleChildArithmetic.place(of: page, in: room, padding: Insets(0), direction: direction))
    }

    private func rowHeight(width: Double?) -> Double {
        let widthSpec = width.map { ViewConstants.spec(ViewConstants.exactly, pixels($0)) } ?? ViewConstants.unspecified
        return Double(row.measure(width: widthSpec, height: ViewConstants.unspecified).height) / density
    }

    override func detach() {
        super.detach()
        onSelection = nil
    }
}
