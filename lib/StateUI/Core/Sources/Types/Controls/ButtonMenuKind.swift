// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a button is by what it holds, which a toolkit makes a control of its own of: a button; one whose click
/// opens its menu; one whose click is its own action, its menu apart.
/// Design: docs/design/views/controls.md#a-buttons-menu
@_spi(Host) public enum ButtonMenuKind: Sendable, Equatable {
    /// A button holding no menu.
    case plain
    /// A button holding a menu and no action of its own: a click opens the menu.
    case menu
    /// A button holding a menu and an action of its own: a split button.
    case split

    /// The kind of a button holding a menu or not, its click heard or not.
    public init(holdsMenu: Bool, clicks: Bool) {
        self = holdsMenu ? (clicks ? .split : .menu) : .plain
    }
}
