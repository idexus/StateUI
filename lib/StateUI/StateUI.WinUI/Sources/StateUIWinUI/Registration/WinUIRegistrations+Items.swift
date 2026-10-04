// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WinUIRegistrations {
    /// An ItemsView: WinUI's own ItemsView, which the host makes itself - its cells ask the tree for what they hold
    /// (`ItemsCells`). Its entries, layout and choice; the user's choosing, invoking and reaching the end; and the
    /// cells it holds.
    static func items(_ registry: Registry<WinUIView>) {
        registry.add(ItemsViewContract.self, madeByHost: WinUIItemsView.self) { list in
            list.applies([
                ItemsViewContract.items, ItemsViewContract.itemsLayout, ItemsViewContract.selectionMode,
                ItemsViewContract.selectedItems, ItemsViewContract.endReachedWithin,
            ]) { view, values in
                view.apply(
                    layout: values[ItemsViewContract.itemsLayout] ?? .list(),
                    mode: values[ItemsViewContract.selectionMode] ?? .none)
            }
            list.raises(ItemsViewContract.selectedItemsChanged)
            list.raises(ItemsViewContract.itemActivated)
            list.raises(ItemsViewContract.endReached)
            list.raises(ItemsViewContract.realizedChanged)
        }
    }
}
