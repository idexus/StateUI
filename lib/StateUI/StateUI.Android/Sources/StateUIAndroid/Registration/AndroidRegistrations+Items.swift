// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// An ItemsView: AndroidX's recycler, which the host makes itself - its cells ask the tree for what they hold
    /// (`ItemsCells`). Its entries, layout and choice; the user's choosing, opening and reaching the end; and the
    /// cells it holds.
    static func items(_ registry: Registry<AndroidView>) {
        registry.add(ItemsViewContract.self, madeByHost: AndroidItemsView.self) { list in
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
