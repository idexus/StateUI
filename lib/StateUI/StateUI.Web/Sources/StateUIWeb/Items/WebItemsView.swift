// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// An ItemsView: a scroller over a cell for each entry, laid out by CSS as a list down, a row across or a grid of
/// columns as wide as fit, a header and a footer across the whole grid; a cell holds its entry's subtree while the
/// browser says it is near the view (`ItemsCells`). The list is a room: it asks for none, and stands where it is put.
/// Design: docs/design/platforms/web/items.md
@MainActor
final class WebItemsView: WebDOMView {
    let cells: ItemsCells

    private let content = WebDOMView(tag: "div")
    private var made: [String: WebItemCell] = [:]
    private var order: [WebItemCell] = []
    private var byNode: [Int32: WebItemCell] = [:]

    /// What hears the cells coming near the view and going away.
    private var nearness: Int32 = 0
    private var shape = ItemsLayout.list()
    private var mode = SelectionMode.none

    /// The entries near the view now, which the end reached is told from.
    private var near: Set<String> = []

    init(cells: ItemsCells) {
        self.cells = cells
        super.init(tag: "div")
        attribute("class", "stateui-items")
        // The room an empty cell keeps, down and across, as every host's does (`ItemsCells.estimatedExtent`).
        style("--stateui-item-down", WebCSS.pixels(ItemsCells.estimatedExtent(across: false)))
        style("--stateui-item-across", WebCSS.pixels(ItemsCells.estimatedExtent(across: true)))
        style("--stateui-chosen-band", WebCSS.number(ChosenBand.opacity * 100) + "%")
        content.attribute("class", "stateui-items-content")
        WebRelay.insert(content.node, into: node, at: 0)
        lay(.list())
        // The user taking the list: where it stands is theirs.
        for event in ["wheel", "touchstart", "pointerdown", "keydown"] {
            listen(event) { [weak self] in self?.cells.userScrolled() }
        }
        nearness = held(WebRelay.listener { [weak self] in self?.nearnessChanged() })
    }

    // MARK: - What the tree says

    /// The entries, the layout, how many may be chosen and which are.
    func apply(layout: ItemsLayout, mode: SelectionMode) {
        if layout != shape { lay(layout) }
        if cells.takeEntries() != nil { writeEntries() }
        self.mode = mode
        attribute("role", mode == .none ? "list" : "listbox")
        attribute("aria-multiselectable", mode == .multiple ? "true" : nil)
        let chosen = Set(cells.selected)
        for cell in order where cells.isItem(cell.entry) {
            cell.attribute("aria-selected", mode == .none ? nil : chosen.contains(cell.entry) ? "true" : "false")
        }
    }

    /// The tree's entries changed: every cell shows the subtree its entry has now, and the entry the program scrolled
    /// to stands again from the cells built.
    func childrenChanged() {
        cells.childrenChanged()
        stand(cells.laidOut())
    }

    /// A cell for each entry, in order: one already made keeps its room, one new is watched for coming near; the
    /// cells of entries gone go in the order they stood.
    private func writeEntries() {
        var kept: [String: WebItemCell] = [:]
        let before = order
        order = cells.identities.map { identity in
            let cell = made[identity] ?? makeCell(identity)
            kept[identity] = cell
            return cell
        }
        for cell in before where kept[cell.entry] !== cell {
            cells.endShowing(in: cell)
            cell.release()
        }
        made = kept
        byNode = Dictionary(uniqueKeysWithValues: order.map { ($0.node, $0) })
        near = near.filter { kept[$0] != nil }
        for (index, cell) in order.enumerated() {
            cell.across = shape.isAcross
            WebRelay.insert(cell.node, into: content.node, at: index)
            cell.attribute("data-part", cells.isItem(cell.entry) ? nil : "")
            cell.attribute("role", cells.isItem(cell.entry) ? (mode == .none ? "listitem" : "option") : "presentation")
        }
    }

    private func makeCell(_ identity: String) -> WebItemCell {
        let cell = WebItemCell(identity)
        cell.hear(.itemTap) { [weak self, weak cell] in
            guard let self, let cell else { return }
            cells.userTapped(cell.entry)
        }
        WebRelay.watchNearness(cell.node, of: node, nearness)
        return cell
    }

    /// Cells came near the view or went away from it, all a frame saw: those going keep the room they take, read
    /// before any changes, the cells take their entries together, telling the tree once, and the item the program
    /// scrolled to stands again once they all have.
    /// Design: docs/design/platforms/web/items.md#a-cell-an-entry
    private func nearnessChanged() {
        var coming: [(identity: String, holding: any ItemsHolding)] = []
        var going: [WebItemCell] = []
        for (element, isNear) in WebRelay.eventNearness {
            guard let cell = byNode[element] else { continue }
            if isNear {
                near.insert(cell.entry)
                coming.append((cell.entry, cell))
            } else {
                near.remove(cell.entry)
                going.append(cell)
            }
        }
        for cell in going { cell.measureRoom() }
        cells.hold(coming, endingShowing: going)
        stand(cells.laidOut())
        cells.showing(near)
    }

    /// The layout as CSS: a column, a row, or a grid of as many columns as fit the narrowest width.
    private func lay(_ layout: ItemsLayout) {
        shape = layout
        switch layout {
        case .list(let spacing):
            attribute("data-layout", "list")
            content.style("gap", WebCSS.pixels(spacing))
            content.style("grid-template-columns", nil)
        case .row(let spacing):
            attribute("data-layout", "row")
            content.style("gap", WebCSS.pixels(spacing))
            content.style("grid-template-columns", nil)
        case .grid(let width, let spacing):
            attribute("data-layout", "grid")
            content.style("gap", WebCSS.pixels(spacing))
            let narrowest = WebCSS.pixels(width) ?? "0px"
            content.style("grid-template-columns", "repeat(auto-fill, minmax(min(100%, \(narrowest)), 1fr))")
        }
    }

    /// Scrolls the entry of `identity` into view at once, standing where `anchor` says - and again as the cells near
    /// it come and take their entries, while the host layer holds it. A scroll gliding there would build every entry
    /// it passed, each then keeping its own size, and the entry would stand elsewhere when it arrived.
    /// Design: docs/design/platforms/web/items.md#scrolling-to-an-item
    func scroll(to identity: String, anchor: ScrollAnchor) {
        guard made[identity] != nil else { return }
        cells.scroll(to: identity, anchor: anchor)
        stand(cells.scrollTarget)
    }

    /// Scrolls the entry `target` names into view, standing where its anchor says.
    private func stand(_ target: ItemsScrollTarget?) {
        guard let target, let cell = made[target.identity] else { return }
        WebRelay.scrollIntoView(cell.node, anchor: target.anchor.rawValue)
    }

    override func release() {
        for cell in order { cell.release() }
        content.release()
        super.release()
    }
}
