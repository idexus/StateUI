// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// Menus: an item's entry, and the context menu a view offers - written from its menu slot as the user asks.
/// Design: docs/design/platforms/android/menus.md
extension AndroidElement {
    /// A menu item or a toolbar item as a menu's item.
    var menuItem: AndroidMenu.Item {
        AndroidMenu.Item(
            text: value(.text)?.string ?? "",
            picture: value(.icon)?.string.flatMap { $0.isEmpty ? nil : $0 },
            isEnabled: value(.isEnabled)?.bool ?? true,
            isDestructive: value(.isDestructive)?.bool == true)
    }

    /// Offers the view's context menu while it carries a menu slot: the slot's entries, written as the user
    /// opens it, each item chosen heard by its element.
    /// Design: docs/design/platforms/android/menus.md#a-context-menu
    func configureContextMenu() {
        guard let view else { return }
        guard children.contains(where: { $0.type == .contextMenu }) else { return view.setMenu(nil) }

        view.setMenu { [weak self, weak view] menu in
            guard let self, let view, let slot = children.first(where: { $0.type == .contextMenu }) else { return }
            var items: [MountedElement] = []
            AndroidMenu.fill(menu, view: view, Self.menuEntries(slot.children, items: &items))
            view.onMenuChose = { index in
                guard items.indices.contains(index) else { return }
                items[index].android.send(.clicked, [])
            }
        }
    }

    /// The entries a menu's elements describe, each item's element held in `items` in the order they come;
    /// Android's context menus draw no pictures.
    private static func menuEntries(_ elements: [AndroidElement], items: inout [MountedElement]) -> [AndroidMenu.Entry] {
        var entries: [AndroidMenu.Entry] = []
        for element in elements {
            switch element.type {
            case .menuItem:
                var item = element.menuItem
                item.picture = nil
                items.append(element.element)
                entries.append(.item(item))
            case .menu:
                entries.append(.menu(
                    element.value(.text)?.string ?? "", isEnabled: element.value(.isEnabled)?.bool ?? true,
                    menuEntries(element.children, items: &items)))
            case .menuSeparator:
                entries.append(.separator)
            default:
                break
            }
        }
        return entries
    }
}
