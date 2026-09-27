// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A cell of an ItemsView: a StateUI panel the relay stands in an `ItemContainer`, holding one entry's subtree placed
/// by the layer's arithmetic. WinUI measures it, and it answers with the room its entry takes.
/// Design: docs/design/platforms/winui/items.md#a-cell
@MainActor
final class WinUIItemCell: WinUISingleChildView, ItemsHolding {
    /// The identity held, where the cell holds one.
    private(set) var identity: String?

    /// The entry whose subtree the cell shows, where it shows one.
    private(set) weak var shown: MountedElement?

    /// Whether the cell is as tall as the list, and asks for its width - in a row.
    var across = false

    func hold(_ identity: String, _ item: MountedElement?) {
        self.identity = identity
        guard item !== shown || items.isEmpty != (item == nil) else { return }
        shown = item
        setItems(item?.winUI.layoutItem.map { [$0] } ?? [])
    }

    func letGo() {
        identity = nil
        shown = nil
        setItems([])
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
