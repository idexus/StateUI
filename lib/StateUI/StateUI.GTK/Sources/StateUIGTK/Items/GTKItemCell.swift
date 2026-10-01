// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIGTK

/// A cell of an ItemsView: a StateUI panel set as a list item's child, holding one entry's subtree placed by the
/// layer's arithmetic; GTK measures it, and it answers with the room its entry takes. Its margins are the room the
/// host layer gives its entry (`ItemsPlacement`).
/// Design: docs/design/platforms/gtk/items.md#a-cell
@MainActor
final class GTKItemCell: GTKSingleChildView, ItemsHolding {
    /// The identity held, where the cell holds one.
    private(set) var identity: String?

    /// The entry whose subtree the cell shows, where it shows one.
    private(set) weak var shown: MountedElement?

    /// Whether the cell is as tall as the list, and asks for its width - in a row.
    var across = false

    /// The entry's place in the list, as its list item last said.
    var place: Int?

    /// The list item the cell stands in, which the screen reader names the row by.
    var row: OpaquePointer?
    private var named = ""

    func hold(_ identity: String, _ item: MountedElement?) {
        self.identity = identity
        guard item !== shown || items.isEmpty != (item == nil) else { return }
        shown = item
        setItems(item?.gtk.layoutItem.map { [$0] } ?? [])
    }

    func letGo() {
        identity = nil
        shown = nil
        setItems([])
    }

    /// Arranges the entry, and names the row by what it says, where that changed: the screen reader reads a row by
    /// its name alone (`MountedElement.spokenWords`).
    override func arrange(in bounds: Rect) {
        super.arrange(in: bounds)
        let words = shown?.spokenWords ?? ""
        guard words != named, let row else { return }
        named = words
        gtk_list_item_set_accessible_label(row, words)
    }

    /// The room around the entry, in the reading direction.
    func keep(_ room: ItemsPlacement.Room) {
        gtk_widget_set_margin_start(widget, Int32(room.leading.rounded()))
        gtk_widget_set_margin_top(widget, Int32(room.top.rounded()))
        gtk_widget_set_margin_end(widget, Int32(room.trailing.rounded()))
    }

    /// A cell whose entry is still on its way keeps the room of a row: measured of nothing, every cell would fit in
    /// view at once, and the list would ask for every entry.
    override func contentSize(width: Double?) -> LayoutSize {
        guard shown != nil, !items.isEmpty else {
            return across ? LayoutSize(width: 44, height: 0) : LayoutSize(width: width ?? 0, height: 44)
        }
        return super.contentSize(width: width)
    }
}
