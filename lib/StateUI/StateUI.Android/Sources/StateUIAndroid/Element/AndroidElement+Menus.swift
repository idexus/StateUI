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
            picture: HostPicture(value(.icon)),
            isEnabled: element.isEffectivelyEnabled,
            isDestructive: value(.isDestructive)?.bool == true,
            shortcut: element.keyboardShortcut)
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
            AndroidMenu.fill(menu, view: view, Self.menuEntries(MenuEntry.entries(of: slot.element), items: &items))
            view.onMenuChose = { index in
                guard items.indices.contains(index) else { return }
                items[index].android.choose()
            }
        }
    }

    /// Gives a button holding a menu its menu: its entries written as it opens, each item chosen heard by its element.
    func configureButtonMenu() {
        guard let button = view as? AndroidButtonView else { return }
        let kind = ButtonMenu.kind(of: element)
        button.setMenu(kind) { [weak self, weak button] menu in
            guard let self, let button else { return }
            var items: [MountedElement] = []
            AndroidMenu.fill(menu, view: button, Self.menuEntries(ButtonMenu.entries(of: element), items: &items))
            button.onMenuChose = { index in
                guard items.indices.contains(index) else { return }
                items[index].android.choose()
            }
        }
    }

    /// The entries the host layer walks, each item's element appended to `items` in the order the menu numbers
    /// them and told its place there; Android's menus draw no pictures.
    static func menuEntries(_ entries: [MenuEntry], items: inout [MountedElement]) -> [AndroidMenu.Entry] {
        entries.map { entry in
            switch entry.kind {
            case .item:
                guard let element = entry.element else { return .separator }
                element.android.menuPlace = items.count
                items.append(element)
                return .item(AndroidMenu.Item(
                    text: entry.title, isEnabled: entry.isEnabled, isDestructive: entry.isDestructive,
                    isOn: entry.isOn, shortcut: entry.keyboardShortcut))
            case .submenu:
                return .menu(entry.title, isEnabled: entry.isEnabled, menuEntries(entry.entries, items: &items))
            case .separator:
                return .separator
            }
        }
    }
}
