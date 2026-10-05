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
    private var shape = ItemsLayout.list()
    private var mode = SelectionMode.none

    /// The entries near the view now, which the end reached is told from.
    private var near: Set<String> = []

    /// An entry scrolled to, stood there again once the entries around it are built - their own sizes, where the
    /// cells kept a row's room, move it.
    private var scrolledTo: (identity: String, anchor: ScrollAnchor)?

    init(cells: ItemsCells) {
        self.cells = cells
        super.init(tag: "div")
        attribute("class", "stateui-items")
        content.attribute("class", "stateui-items-content")
        WebRelay.insert(content.node, into: node, at: 0)
        lay(.list())
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

    /// The tree's entries changed: every cell shows the subtree its entry has now.
    func childrenChanged() {
        cells.childrenChanged()
        guard let scrolledTo, made[scrolledTo.identity]?.shown != nil else { return }
        self.scrolledTo = nil
        scroll(to: scrolledTo.identity, anchor: scrolledTo.anchor, again: false)
    }

    /// A cell for each entry, in order: one already made keeps its room, one new is watched for coming near.
    private func writeEntries() {
        var kept: [String: WebItemCell] = [:]
        order = cells.identities.map { identity in
            let cell = made[identity] ?? makeCell(identity)
            kept[identity] = cell
            return cell
        }
        for (identity, cell) in made where kept[identity] == nil {
            cells.endShowing(in: cell)
            cell.detach()
        }
        made = kept
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
        cell.listen("itemtap") { [weak self, weak cell] in
            guard let self, let cell else { return }
            cells.userTapped(cell.entry)
        }
        WebRelay.watchNearness(cell.node, of: node, WebRelay.listener { [weak self, weak cell] in
            guard let self, let cell else { return }
            nearnessChanged(cell, isNear: WebRelay.eventNear)
        })
        return cell
    }

    /// A cell came near the view, or went away from it: it holds its entry, or lets it go to the tree's reach.
    private func nearnessChanged(_ cell: WebItemCell, isNear: Bool) {
        if isNear {
            near.insert(cell.entry)
            cells.hold(cell.entry, in: cell)
        } else {
            near.remove(cell.entry)
            cells.endShowing(in: cell)
        }
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

    /// Scrolls the entry of `identity` into view at once, standing where `anchor` says - and again, `again`, once
    /// it and its neighbours are built. A scroll gliding there would build every entry it passed, each then keeping
    /// its own size, and the entry would stand elsewhere when it arrived.
    func scroll(to identity: String, anchor: ScrollAnchor, again: Bool = true) {
        guard let cell = made[identity] else { return }
        WebRelay.scrollIntoView(cell.node, anchor: anchor.rawValue)
        if again, cell.shown == nil { scrolledTo = (identity, anchor) }
    }

    override func detach() {
        for cell in order { cell.detach() }
        content.detach()
        super.detach()
    }
}
