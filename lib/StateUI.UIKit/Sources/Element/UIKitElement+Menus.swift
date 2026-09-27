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
            view.addInteraction(UIContextMenuInteraction(delegate: menu))
            contextMenu = menu
        } else if !holds, let menu = contextMenu {
            view.interactions.filter { $0 is UIContextMenuInteraction }.forEach(view.removeInteraction)
            _ = menu
            contextMenu = nil
        }
    }

    /// The context menu as it stands now; nil where the view offers none.
    var builtContextMenu: UIMenu? {
        contextMenuSlot.map { UIKitMenus.menu(MenuEntry.entries(of: $0)) }
    }

    /// The slot the view's context menu stands in, a child of its own.
    private var contextMenuSlot: MountedElement? {
        element.children.first { $0.type == .contextMenu }
    }
}
#endif
