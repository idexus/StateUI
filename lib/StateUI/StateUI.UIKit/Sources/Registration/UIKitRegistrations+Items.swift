// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension UIKitRegistrations {
    /// An ItemsView: UIKit's collection view, which the host makes itself - its cells ask the tree for what they
    /// hold (`ItemsCells`). Its entries, layout and choice; the user's choosing, opening and reaching the end; the
    /// cells it holds; and scrolling to an item.
    static func items(_ registry: Registry<UIView>) {
        registry.add(ItemsViewContract.self, madeByHost: UIKitItemsView.self) { list in
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

    /// The acts an ItemsView answers itself.
    static let itemsActs: [any ContractMember] = [ItemsViewContract.scrollTo]
}
#endif
