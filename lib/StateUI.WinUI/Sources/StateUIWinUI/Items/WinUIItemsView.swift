// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// An ItemsView: a StateUI layout holding WinUI's own ItemsView over the list's identities, a cell holding each
/// entry's subtree as the list asks for it (`ItemsCells`). WinUI scrolls, reuses its containers, chooses, invokes and
/// tells Narrator; StateUI builds what a cell holds. The list is a room: it asks for none, and stands where it is put.
/// Design: docs/design/platforms/winui/items.md
@MainActor
final class WinUIItemsView: WinUILayoutView {
    let cells: ItemsCells

    /// WinUI's own list, which the relay's callbacks name.
    let list = WinUIItemsList()

    private var shape = ItemsLayout.list()
    private var choice: Choice?

    /// Every cell the list asked for: the relay keeps each container for the list's life, so each cell is the list's.
    private var made: [WinUIItemCell] = []

    /// Whether the list left the tree: what WinUI still says is heard by nobody.
    private var released = false

    /// Whether the motion of a scroll the tree asks for is left out.
    private let reducesMotion: () -> Bool

    private struct Choice: Equatable {
        var chosen: [String]
        var mode: SelectionMode
        var invokable: Bool
    }

    init(cells: ItemsCells, reducesMotion: @escaping () -> Bool) {
        self.cells = cells
        self.reducesMotion = reducesMotion
        super.init()
        list.owner = self
        list.placingLayout = self
        setChildren([list])
    }

    // MARK: - What the tree says

    /// The entries, the layout, how many may be chosen and which are.
    func apply(layout: ItemsLayout, mode: SelectionMode) {
        if let changes = cells.takeEntries() { writeEntries(changes) }
        if layout != shape {
            shape = layout
            let (kind, spacing, minimum): (Int32, Double, Double) = switch layout {
            case .list(let spacing): (0, spacing, 0)
            case .row(let spacing): (1, spacing, 0)
            case .grid(let minimum, let spacing): (2, spacing, minimum)
            }
            stateui_winui_items_set_layout(list.handle, kind, spacing, minimum)
            invalidateMeasurements()
        }
        let choice = Choice(
            chosen: cells.selected, mode: mode, invokable: cells.element?.handler(.itemActivated) != nil)
        guard choice != self.choice else { return }
        self.choice = choice
        WinUIStrings.withCStrings(choice.chosen) { chosen in
            stateui_winui_items_set_choice(
                list.handle, choice.mode.rawValue, chosen, Int32(choice.chosen.count), choice.invokable)
        }
    }

    /// The identities with their kinds, and the changes as runs.
    private func writeEntries(_ changes: ItemsChanges) {
        let entries = cells.entries
        var edges = Set([entries.header, entries.footer].compactMap(\.self))
        for section in entries.sections { edges.formUnion([section.header, section.footer].compactMap(\.self)) }
        let identities = cells.identities
        let kinds = identities.map { edges.contains($0) ? Int32(1) : 0 }
        let runs = { (runs: [Range<Int>]) in runs.flatMap { [Int32($0.lowerBound), Int32($0.count)] } }
        let (removed, inserted) = (runs(changes.removedRuns), runs(changes.insertedRuns))
        WinUIStrings.withCStrings(identities) { names in
            stateui_winui_items_set_entries(
                list.handle, names, kinds, Int32(identities.count), removed, Int32(removed.count), inserted,
                Int32(inserted.count))
        }
    }

    /// The tree's entries changed: every cell shows the subtree its entry has now (`ItemsCells.childrenChanged`).
    func childrenChanged() {
        cells.childrenChanged()
    }

    /// An entry's size would change: the cell holding it is measured again.
    func remeasure(_ item: MountedElement) {
        guard let identity = cells.identity(of: item) else { return }
        (cells.holding(of: identity) as? WinUIItemCell)?.invalidateMeasurements()
    }

    // MARK: - Its room

    /// As wide as it is offered and as tall as nothing asks: its room is what its layout gives it.
    override func contentSize(width: Double?) -> LayoutSize {
        LayoutSize(width: width ?? 0, height: 0)
    }

    /// Measures WinUI's list with no room the way it scrolls: its viewport is the place it is given, never the
    /// length of all its items.
    /// Design: docs/design/platforms/winui/layout.md#scrolling
    override func measure(width: Double, height: Double) -> LayoutSize {
        let across = shape.isAcross
        _ = list.measure(
            width: across ? 0 : (width.isFinite ? width : nil), height: across ? (height.isFinite ? height : nil) : 0)
        return super.measure(width: width, height: height)
    }

    override func arrange(in bounds: Rect) {
        list.layout(bounds)
    }

    // MARK: - What the list says

    /// A new cell, of an item or of a header or a footer; the list keeps it.
    func makeCell(item: Bool) -> WinUIItemCell {
        let cell = WinUIItemCell()
        cell.across = shape.isAcross
        made.append(cell)
        return cell
    }

    func held(_ identity: String, in number: Int64) {
        guard !released, let cell = WinUIView.find(number) as? WinUIItemCell else { return }
        cell.across = shape.isAcross
        cells.hold(identity, in: cell)
    }

    func letGo(_ number: Int64) {
        guard !released, let cell = WinUIView.find(number) as? WinUIItemCell else { return }
        cells.endShowing(in: cell)
    }

    func chose(_ identities: [String]) {
        guard !released else { return }
        cells.userChose(identities)
    }

    func invoked(_ identity: String) {
        guard !released else { return }
        cells.userActivated(identity)
    }

    func showing(_ places: ClosedRange<Int>) {
        guard !released else { return }
        let identities = cells.identities
        cells.showing(places.clamped(to: 0...max(identities.count - 1, 0)).compactMap {
            identities.indices.contains($0) ? identities[$0] : nil
        })
    }

    // MARK: - Acts

    /// Brings the item of `identity` where `anchor` says.
    func scroll(to identity: String, anchor: ScrollAnchor) {
        guard let place = cells.identities.firstIndex(of: identity) else { return }
        stateui_winui_items_scroll_to(list.handle, Int32(place), anchor.rawValue, !reducesMotion())
    }

    /// The list left: WinUI lets its cells go, and they leave with it.
    override func detach() {
        super.detach()
        released = true
        stateui_winui_items_release(list.handle)
        made.removeAll()
    }

    // MARK: - For the tests

    /// The items WinUI holds chosen, in the order they show.
    var selectedForTesting: [String] {
        let chosen = Set(WinUIStrings.read { stateui_winui_items_chosen(list.handle, $0, $1) }
            .split(separator: "\n").map(String.init))
        return cells.identities.filter(chosen.contains)
    }

    /// How many items WinUI lets the user choose.
    var modeForTesting: SelectionMode {
        SelectionMode(rawValue: stateui_winui_items_mode(list.handle)) ?? .none
    }
}

/// WinUI's own ItemsView, which the relay's callbacks name by its number and which hands them to its list.
@MainActor
final class WinUIItemsList: WinUIView {
    weak var owner: WinUIItemsView?

    init() {
        super.init { number in stateui_winui_items_make(number) }
    }

    /// The list a callback names; nil once it has left.
    static func find(_ number: Int64) -> WinUIItemsView? {
        (WinUIView.find(number) as? WinUIItemsList)?.owner
    }
}
