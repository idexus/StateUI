// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A button's menu (`Button.menu`), read alike on every host: the kind of control the button is, from the patch it
/// is made from or as it stands, and the entries its menu holds.
/// Design: docs/design/views/controls.md#a-buttons-menu
@_spi(Host) @MainActor public enum ButtonMenu {
    /// The kind of control a button made from `patch` is: its menu among its children, its click heard or not.
    public static func kind(made patch: HostPatch?) -> ButtonMenuKind {
        guard let patch, patch.type == .button else { return .plain }
        let holdsMenu = if case .arranged(let children) = patch.children {
            children.contains { $0.type == .buttonMenu }
        } else {
            false
        }
        let clicks = if case .replace(let events) = patch.events { events[.clicked] != nil } else { false }
        return ButtonMenuKind(holdsMenu: holdsMenu, clicks: clicks)
    }

    /// The kind of control `button` is as it stands.
    public static func kind(of button: MountedElement) -> ButtonMenuKind {
        guard button.type == .button else { return .plain }
        return ButtonMenuKind(holdsMenu: menu(of: button) != nil, clicks: button.handler(.clicked) != nil)
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
