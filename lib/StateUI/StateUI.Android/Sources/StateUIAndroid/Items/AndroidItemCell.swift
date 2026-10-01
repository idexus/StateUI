// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A cell of an ItemsView: the relay's `StateUIItemCell`, which the recycler measures and places, holding one entry's
/// subtree placed by the layer's arithmetic. A tap on an item's cell goes to its list.
/// Design: docs/design/platforms/android/items.md#a-cell
@MainActor
final class AndroidItemCell: AndroidSingleChildView, ItemsHolding {
    /// The identity held, where the cell holds one.
    private(set) var identity: String?

    /// The entry whose subtree the cell shows, where it shows one.
    private(set) weak var shown: MountedElement?

    /// The list the cell stands in.
    weak var list: AndroidItemsView?

    /// Whether the cell is as tall as the list, and asks for its width - in a row.
    var across = false

    /// A cell of an item, or of a header or a footer.
    init(item: Bool) {
        super.init(making: { number in
            Java.new(
                JavaAPI.itemCell, JavaAPI.newItemCell, .object(AndroidRenderer.context), .long(number), .bool(item))
        })
        if item { listen(JavaAPI.setOnClickListener) }
    }

    func hold(_ identity: String, _ item: MountedElement?) {
        self.identity = identity
        guard item !== shown || items.isEmpty != (item == nil) else { return }
        shown = item
        setItems(item?.android.layoutItem.map { [$0] } ?? [])
    }

    func letGo() {
        identity = nil
        shown = nil
        setItems([])
    }

    /// A cell whose entry is still on its way keeps the room of a row: measured of nothing, every cell would fit in
    /// view at once, and the recycler would ask for every entry.
    override func contentSize(width: Double?) -> LayoutSize {
        guard shown != nil, !items.isEmpty else {
            return across ? LayoutSize(width: 44, height: 0) : LayoutSize(width: width ?? 0, height: 44)
        }
        return super.contentSize(width: width)
    }

    override func clicked() {
        guard let identity else { return }
        list?.tapped(identity)
    }
}
