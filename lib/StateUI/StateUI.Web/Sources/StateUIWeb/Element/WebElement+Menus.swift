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
        listensForMenu = true
        view.listen("menu") { [weak self] in
            guard let self, let declared = element.children.first(where: { $0.type == .contextMenu }) else { return }
            WebMenu(MenuEntry.entries(of: declared)).show(at: WebRelay.eventPointer.at)
        }
    }
}
