// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A cell of an ItemsView: one for each entry, holding the entry's subtree while it is near the list's view, and
/// keeping the room it took while it holds none - a row's before its entry first comes.
/// Design: docs/design/platforms/web/items.md#a-cell-an-entry
@MainActor
final class WebItemCell: WebLayoutView, ItemsHolding {
    /// The identity held, where the cell holds one.
    private(set) var identity: String?

    /// The entry whose subtree the cell shows, where it shows one.
    private(set) weak var shown: MountedElement?

    /// The identity the cell stands for in the list, whether it holds it or not.
    let entry: String

    init(_ entry: String) {
        self.entry = entry
        super.init(arrangement: .single)
        attribute("class", "stateui-item")
    }

    /// Whether the list runs across, so a cell keeps its width rather than its height while it holds nothing.
    var across = false

    func hold(_ identity: String, _ item: MountedElement?) {
        self.identity = identity
        guard item !== shown || children.isEmpty != (item == nil) else { return }
        shown = item
        let placed = item?.web.placedElement
        if placed != nil { keep(nil) }
        setItems(placed.map { [($0.view!, $0.element.layoutValues)] } ?? [])
    }

    /// The cell lets its entry go, keeping the room it took: the cells after it stand where they stood.
    func letGo() {
        identity = nil
        shown = nil
        guard !children.isEmpty else { return }
        keep(WebRelay.size(of: node))
        setItems([])
    }

    /// The room the cell keeps while it holds nothing; nil for its entry's own.
    private func keep(_ room: LayoutSize?) {
        style(across ? "min-width" : "min-height", room.flatMap { WebCSS.pixels(across ? $0.width : $0.height) })
    }
}
