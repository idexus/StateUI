// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A button's menu (`.menu` on a `Button` or a `ToolbarButton`), read alike on every host: how it opens, from the
/// patch the button is made from or as it stands, whether its arrow shows, the entries its menu holds, and what a
/// bar's button holding one offers behind the bar's overflow.
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

    /// How `button` - a button or a bar's button - opens its menu as it stands.
    public static func opening(of button: MountedElement) -> ButtonMenuOpening {
        guard button.type == .button || button.type == .toolbarButton else { return .none }
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

    /// What a bar's button holding a menu offers behind the bar's overflow, as a submenu under its words: its own
    /// action first where its click is its own, a line, then its menu's entries; none for a button holding no menu.
    /// Design: docs/design/host/pages.md#a-bar-buttons-menu
    public static func inOverflow(_ button: MountedElement) -> [MenuEntry] {
        let entries = entries(of: button)
        guard !entries.isEmpty, opening(of: button) != .click else { return entries }
        return [MenuEntry.entry(of: button), .separator] + entries
    }

    /// A bar's item as its overflow lists it: an item, or - a button holding a menu - a submenu under its words
    /// holding what it offers there (`inOverflow`).
    public static func overflowEntry(of item: MountedElement) -> MenuEntry {
        let offered = inOverflow(item)
        return offered.isEmpty ? MenuEntry.entry(of: item) : MenuEntry(menu: item, entries: offered)
    }
}
