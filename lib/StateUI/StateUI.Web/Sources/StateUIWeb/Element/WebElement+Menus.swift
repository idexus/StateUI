// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view's context menu on the Web: the menu its element declares, as its entries stand when the user asks for it.
/// Design: docs/design/platforms/web/pages.md#menus
extension WebElement {
    /// Listens on the view for the user's asking for its menu - a right click, a finger held still - once its element
    /// declares a context menu; a menu of no entries shows nothing.
    func offerContextMenu() {
        guard let view, !listensForMenu, element.children.contains(where: { $0.type == .contextMenu }) else { return }
        // A button holding a menu offers that one (offerButtonMenu).
        guard ButtonMenu.opening(of: element) == .none else { return }
        listensForMenu = true
        view.listenForMenu { [weak self] in
            guard let self, let declared = element.children.first(where: { $0.type == .contextMenu }) else { return }
            WebMenu(MenuEntry.entries(of: declared)).show(at: WebRelay.eventPointer.at)
        }
    }

    /// Makes a button holding a menu open it, its entries as they stand then, under the button, as the button
    /// opens it: its click, an arrow of its own, or as the user asks for a menu. How a button opens its menu is its
    /// own for good; whether its arrow shows follows the tree.
    func offerButtonMenu() {
        guard let button = view as? WebButtonView else { return }
        let opening = ButtonMenu.opening(of: element)
        guard opening != .none else { return }
        button.showsMenuArrow(ButtonMenu.showsArrow(element) || opening == .arrow)
        guard !listensForButtonMenu else { return }
        listensForButtonMenu = true
        button.holdMenu(opening) { [weak self, weak button] in
            guard let self, let button else { return }
            WebMenu(ButtonMenu.entries(of: element)).show(under: button)
        }
    }
}
