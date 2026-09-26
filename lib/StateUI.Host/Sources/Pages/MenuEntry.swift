// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One entry of a menu as every host walks it - an item, a separator, or a submenu holding entries of its own - with
/// its caption, whether it can be chosen and its identifier; the host turns the walk into its toolkit's menu.
/// Design: docs/design/host/pages.md#menus
@_spi(Host) @MainActor public struct MenuEntry {
    /// What an entry is.
    public enum Kind: Sendable {
        /// An item the user chooses.
        case item

        /// A line between items.
        case separator

        /// A submenu, holding entries of its own.
        case submenu
    }

    /// What the entry is.
    public let kind: Kind

    /// The element: an item's, which hears it chosen, or a submenu's; nil for a separator.
    public let element: MountedElement?

    /// The caption; empty for a separator.
    public let title: String

    /// Whether the user can choose it.
    public let isEnabled: Bool

    /// The identifier a test and assistive technology find it by, where one is said.
    public let identifier: String?

    /// A submenu's entries, in order.
    public let entries: [MenuEntry]

    /// The entries `container` holds - a menu, a context menu, a submenu - in order; what is none of them is none.
    public static func entries(of container: MountedElement) -> [MenuEntry] {
        container.children.compactMap { entry in
            switch entry.type {
            case .menuItem: MenuEntry(entry, kind: .item, entries: [])
            case .menuSeparator: MenuEntry(nil, kind: .separator, entries: [])
            case .menu: MenuEntry(entry, kind: .submenu, entries: entries(of: entry))
            default: nil
            }
        }
    }

    /// The menus a menu bar holds, in order - what else stands at its top stands on no bar.
    public static func menus(of bar: MountedElement) -> [MenuEntry] {
        bar.children.filter { $0.type == .menu }.map { MenuEntry($0, kind: .submenu, entries: entries(of: $0)) }
    }

    private init(_ element: MountedElement?, kind: Kind, entries: [MenuEntry]) {
        self.kind = kind
        self.element = element
        title = element?.value(.text)?.string ?? ""
        isEnabled = element?.value(.isEnabled)?.bool ?? true
        identifier = element?.value(.accessibilityIdentifier)?.string
        self.entries = entries
    }
}
