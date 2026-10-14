// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// How a button's menu opens, which a toolkit makes a control of its own of: no menu; the button's click; an arrow
/// of its own beside the button's click; held, the click the button's own.
/// Design: docs/design/views/controls.md#a-buttons-menu
@_spi(Host) public enum ButtonMenuOpening: Sendable, Equatable {
    /// A button holding no menu.
    case none
    /// The button's click opens its menu.
    case click
    /// A split button: its click its own, an arrow of its own opening the menu.
    case arrow
    /// The button's click is its own; held, it opens the menu.
    case hold

    /// How the menu of a button holding one or not opens, its click heard or not, as `kind` asks.
    public init(holdsMenu: Bool, clicks: Bool, kind: ButtonMenuKind) {
        guard holdsMenu else {
            self = .none
            return
        }
        self = switch kind {
        case .automatic: clicks ? .arrow : .click
        case .split: .arrow
        case .held: .hold
        }
    }
}
