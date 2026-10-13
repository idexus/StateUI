// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A button's menu (`Button.menu`), read alike on every host: how it opens, from the patch the button is made from
/// or as it stands, whether its arrow shows, and the entries its menu holds.
/// Design: docs/design/views/controls.md#a-buttons-menu
@_spi(Host) @MainActor public enum ButtonMenu {
    /// How a button made from `patch` opens its menu: its menu among its children, its click heard or not, the kind
    /// it asks.
    public static func opening(made patch: HostPatch?) -> ButtonMenuOpening {
        guard let patch, patch.type == .button else { return .none }
        let holdsMenu = if case .arranged(let children) = patch.children {
            children.contains { $0.type == .buttonMenu }
        } else {
            false
        }
        let clicks = if case .replace(let events) = patch.events { events[.clicked] != nil } else { false }
        let kind = patch.properties[.menuKind].flatMap(ButtonMenuKind.init(propValue:)) ?? .automatic
        return ButtonMenuOpening(holdsMenu: holdsMenu, clicks: clicks, kind: kind)
    }

    /// How `button` opens its menu as it stands.
    public static func opening(of button: MountedElement) -> ButtonMenuOpening {
        guard button.type == .button else { return .none }
        let kind = button.value(.menuKind).flatMap(ButtonMenuKind.init(propValue:)) ?? .automatic
        return ButtonMenuOpening(holdsMenu: menu(of: button) != nil, clicks: button.handler(.clicked) != nil, kind: kind)
    }

    /// Whether a button made from `patch`, opening its menu by its click, shows the arrow saying so: unless the patch
    /// says it shows none.
    public static func showsArrow(made patch: HostPatch?) -> Bool {
        opening(made: patch) == .click && patch?.properties[.showsMenuArrow]?.bool != false
    }

    /// Whether a button opening its menu by its click shows the arrow saying so: unless the tree says it shows none.
    public static func showsArrow(_ button: MountedElement) -> Bool {
        opening(of: button) == .click && button.value(.showsMenuArrow)?.bool != false
    }

    /// The entries `button`'s menu holds, in order; none for a button holding no menu.
    public static func entries(of button: MountedElement) -> [MenuEntry] {
        menu(of: button).map(MenuEntry.entries(of:)) ?? []
    }

    /// The menu `button` holds, where it holds one.
    public static func menu(of button: MountedElement) -> MountedElement? {
        button.children.first { $0.type == .buttonMenu }
    }
}
