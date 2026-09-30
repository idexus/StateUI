// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// One entry of a menu as every host walks it - an item, a separator, or a submenu holding entries of its own - with
/// its caption, its picture, whether it can be chosen, whether it destroys something and its identifier; the host
/// turns the walk into its toolkit's menu.
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

    /// The picture shown with the caption, by name, where one is said.
    public let icon: String?

    /// Whether the user can choose it.
    public let isEnabled: Bool

    /// Whether choosing it destroys something, which the platform marks.
    public let isDestructive: Bool

    /// The identifier a test and assistive technology find it by, where one is said.
    public let identifier: String?

    /// A submenu's entries, in order.
    public let entries: [MenuEntry]

    /// The platform's menu this one joins, where its `.id` is a `StandardMenu`.
    public var standard: StandardMenu? {
        guard case .manual(let identity) = element?.id else { return nil }
        return StandardMenu(identity: identity)
    }

    /// The entries `container` holds - a menu, a context menu, a submenu - in order; what is none of them is none.
    public static func entries(of container: MountedElement) -> [MenuEntry] {
        container.children.compactMap { entry in
            switch entry.type {
            case .menuItem: MenuEntry(entry, kind: .item, entries: [])
            case .menuSeparator: .separator
            case .menu: MenuEntry(entry, kind: .submenu, entries: entries(of: entry))
            default: nil
            }
        }
    }

    /// A line between two sections.
    static var separator: MenuEntry { MenuEntry(nil, kind: .separator, entries: []) }

    /// The menu `head` holding `entries`, composed from it and the menus joining it.
    init(menu head: MountedElement, entries: [MenuEntry]) {
        self.init(head, kind: .submenu, entries: entries)
    }

    private init(_ element: MountedElement?, kind: Kind, entries: [MenuEntry]) {
        self.kind = kind
        self.element = element
        title = element?.value(.text)?.string ?? ""
        icon = element?.value(.icon)?.string.flatMap { $0.isEmpty ? nil : $0 }
        isEnabled = element?.value(.isEnabled)?.bool ?? true
        isDestructive = element?.value(.isDestructive)?.bool == true
        identifier = element?.value(.accessibilityIdentifier)?.string
        self.entries = entries
    }
}
