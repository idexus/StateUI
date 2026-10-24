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

    /// The picture shown with the caption, where one is said.
    public let icon: HostPicture?

    /// Whether the user can choose it.
    public let isEnabled: Bool

    /// Whether choosing it destroys something, which the platform marks.
    public let isDestructive: Bool

    /// The identifier a test and assistive technology find it by, where one is said.
    public let identifier: String?

    /// Whether an item stands checked, or not; nil for one standing neither way, which shows no mark.
    public let isOn: Bool?

    /// The shortcut an item states, shown beside its words; nil for none, and for a submenu or a line.
    /// Design: docs/design/types/keyboard.md#on-each-platform
    public let keyboardShortcut: KeyboardShortcut?

    /// A submenu's entries, in order.
    public let entries: [MenuEntry]

    /// What the entry does to the field holding the keyboard, where it is one an Edit menu keeps itself; nil for an
    /// entry of the tree's.
    public let edit: EditCommand?

    /// Everything an entry shows and the element it answers, holding no element: a host builds a menu it cannot
    /// change in place again where what its entries say differs.
    public struct Said: Equatable, Sendable {
        let kind: Kind
        let mount: UInt64?
        let title: String
        let icon: HostPicture?
        let isEnabled: Bool
        let isDestructive: Bool
        let identifier: String?
        let isOn: Bool?
        let keyboardShortcut: KeyboardShortcut?
        let entries: [Said]
        let edit: EditCommand?
    }

    /// What the entry says, its submenu's entries with it.
    public var said: Said {
        Said(
            kind: kind, mount: element?.mount, title: title, icon: icon, isEnabled: isEnabled,
            isDestructive: isDestructive, identifier: identifier, isOn: isOn, keyboardShortcut: keyboardShortcut,
            entries: entries.map(\.said), edit: edit)
    }

    /// The platform's menu this one joins, where its `.id` is a `StandardMenu`.
    public var standard: StandardMenu? {
        guard case .manual(let identity) = element?.id else { return nil }
        return StandardMenu(identity: identity)
    }

    /// The entries `container` holds - a menu, a context menu, a submenu - in order; what is none of them is none.
    public static func entries(of container: MountedElement) -> [MenuEntry] {
        container.children.compactMap { entry in
            switch entry.type {
            case .menuItem, .menuToggle: MenuEntry(entry, kind: .item, entries: [])
            case .menuSeparator: .separator
            case .menu: MenuEntry(entry, kind: .submenu, entries: entries(of: entry))
            default: nil
            }
        }
    }

    /// The picture `element` shows: a bar's setting its `on:` picture while it stands on, else its own.
    /// Design: docs/design/host/pages.md#a-checked-entry
    static func picture(of element: MountedElement?) -> HostValue? {
        guard let element else { return nil }
        if element.type == .toolbarToggle, element.value(.isOn)?.bool == true, let on = element.value(.onIcon) { return on }
        return element.value(.icon)
    }

    /// A line between two sections.
    public static var separator: MenuEntry { MenuEntry(nil, kind: .separator, entries: []) }

    /// `element` as a menu's entry - a menu its submenu, anything else an item: a bar's action behind its overflow.
    public static func entry(of element: MountedElement) -> MenuEntry {
        element.type == .menu
            ? MenuEntry(element, kind: .submenu, entries: entries(of: element))
            : MenuEntry(element, kind: .item, entries: [])
    }

    /// The menu `head` holding `entries`, composed from it and the menus joining it.
    init(menu head: MountedElement, entries: [MenuEntry]) {
        self.init(head, kind: .submenu, entries: entries)
    }

    /// The Edit menu's own entry doing `command`, in `words`, showing its shortcut - Redo's as `redo`.
    init(_ command: EditCommand, words: EditWords, redo: KeyboardShortcut) {
        kind = .item
        element = nil
        title = command.title(in: words)
        icon = nil
        isEnabled = true
        isDestructive = false
        identifier = nil
        isOn = nil
        keyboardShortcut = command.shortcut(redo: redo)
        entries = []
        edit = command
    }

    private init(_ element: MountedElement?, kind: Kind, entries: [MenuEntry]) {
        self.kind = kind
        self.element = element
        title = element?.value(.text)?.string ?? ""
        icon = HostPicture(Self.picture(of: element))
        isEnabled = element?.isEffectivelyEnabled ?? true
        isDestructive = element?.value(.role).flatMap(ActionRole.init(propValue:)) == .destructive
        identifier = element?.value(.accessibilityIdentifier)?.string
        isOn = kind == .item ? element?.value(.isOn)?.bool : nil
        keyboardShortcut = kind == .item ? element?.keyboardShortcut : nil
        self.entries = entries
        edit = nil
    }
}
