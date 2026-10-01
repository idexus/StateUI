// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// An ItemsView: AppKit's collection view, which the host makes itself - its cells ask the tree for what they
    /// hold (`ItemsCells`). Its entries, layout and choice; the user's choosing, opening and reaching the end; the
    /// cells it holds; and scrolling to an item.
    static func items(_ registry: Registry<NSView>) {
        registry.add(ItemsViewContract.self, madeByHost: AppKitItemsView.self) { list in
            list.applies([
                ItemsViewContract.items, ItemsViewContract.itemsLayout, ItemsViewContract.selectionMode,
                ItemsViewContract.selectedItems, ItemsViewContract.endReachedWithin,
            ]) { view, values in
                view.apply(
                    layout: values[ItemsViewContract.itemsLayout] ?? .list(),
                    mode: values[ItemsViewContract.selectionMode] ?? .none)
            }
            list.raises(ItemsViewContract.selectionChanged)
            list.raises(ItemsViewContract.itemActivated)
            list.raises(ItemsViewContract.endReached)
            list.raises(ItemsViewContract.realizedChanged)
        }
    }
}
#endif
