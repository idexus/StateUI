// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A view's context menu: its slot stays a child for identity and sparse updates, and is never laid out; UIKit asks
/// for the menu as the user holds the view, and it is built then from what the tree says now.
/// Design: docs/design/platforms/uikit/pages.md#menus
extension UIKitElement {
    func configureContextMenu() {
        guard let view else { return }
        let holds = contextMenuSlot.map { !MenuEntry.entries(of: $0).isEmpty } ?? false
        if holds, contextMenu == nil {
            let menu = UIKitContextMenu(owner: self)
            view.addInteraction(menu.interaction)
            contextMenu = menu
        } else if !holds, let menu = contextMenu {
            // Only its own: a control's own menu - a button's, a picker's - is an interaction of the same kind.
            view.removeInteraction(menu.interaction)
            contextMenu = nil
        }
    }

    /// The context menu as it stands now; nil where the view offers none.
    var builtContextMenu: UIMenu? {
        contextMenuSlot.map { UIKitMenus.menu(MenuEntry.entries(of: $0)) }
    }

    /// Gives a button holding a menu UIKit's menu for it, opened as the button says: by a tap, by a split button's
    /// arrow, or held.
    func configureButtonMenu() {
        guard let button = view as? UIKitButtonView else { return }
        let opening = ButtonMenu.opening(of: element)
        button.offer(
            opening == .none ? nil : UIKitMenus.menu(ButtonMenu.entries(of: element)), opening: opening,
            showsArrow: ButtonMenu.showsArrow(element))
    }

    /// The slot the view's context menu stands in, a child of its own.
    private var contextMenuSlot: MountedElement? {
        element.children.first { $0.type == .contextMenu }
    }
}
#endif
