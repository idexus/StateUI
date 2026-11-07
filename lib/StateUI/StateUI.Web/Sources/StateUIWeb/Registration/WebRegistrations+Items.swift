// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// An ItemsView, which the host makes itself - its cells ask the tree for what they hold (`ItemsCells`). Its
    /// entries, layout and choice; the user's choosing, opening and reaching the end; and the cells it holds.
    static func items(_ registry: Registry<WebDOMView>) {
        registry.add(ItemsViewContract.self, madeByHost: WebItemsView.self) { list in
            list.applies(
                ItemsViewContract.items, ItemsViewContract.itemsLayout, ItemsViewContract.selectionMode,
                ItemsViewContract.selectedItems, ItemsViewContract.endReachedWithin) { view, values in
                view.apply(
                    layout: values[ItemsViewContract.itemsLayout] ?? .list(),
                    mode: values[ItemsViewContract.selectionMode] ?? .none)
            }
            list.declares(ItemsViewContract.selectedItemsChanged)
            list.declares(ItemsViewContract.itemActivated)
            list.declares(ItemsViewContract.endReached)
            list.declares(ItemsViewContract.realizedChanged)
        }
    }
}
