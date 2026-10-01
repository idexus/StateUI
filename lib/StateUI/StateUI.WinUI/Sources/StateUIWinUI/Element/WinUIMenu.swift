// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A menu as the relay takes it: its entries flat - an item, a separator, a submenu opening and closing - each with
/// its caption, whether it can be chosen, an item's picture and whether it destroys something, and what each item
/// does, in the items' order. A menu bar's are its menus, each one's entries within it.
/// Design: docs/design/platforms/winui/pages.md#menus
@MainActor
struct WinUIMenu {
    private(set) var kinds: [Int32] = []
    private(set) var titles: [String] = []
    private(set) var enabled: [Bool] = []
    private(set) var identifiers: [String] = []
    /// The files each entry's picture may stand in (`PictureArithmetic.files`); none for words alone.
    private(set) var icons: [[String]] = []
    private(set) var destructive: [Bool] = []
    private(set) var actions: [() -> Void] = []

    /// The entries `container` holds, as the host layer walks them; none for no container.
    init(_ container: WinUIElement? = nil) {
        if let container { add(MenuEntry.entries(of: container.element)) }
    }

    /// The menus of a menu bar, as the host layer composes them.
    init(menus: [MenuEntry]) {
        add(menus)
    }

    /// Whether the menu has no entries.
    var isEmpty: Bool { kinds.isEmpty }

    /// Whether the menu draws as `other` does: the same entries, captions, choosable ones, pictures and marks.
    func draws(like other: WinUIMenu) -> Bool {
        kinds == other.kinds && titles == other.titles && enabled == other.enabled && identifiers == other.identifiers
            && icons == other.icons && destructive == other.destructive
    }

    /// Hands `write` the entries as the relay takes them: their kinds, captions, whether each can be chosen, the
    /// identifiers, the files each picture may stand in, whether each destroys something, and how many there are.
    func relayed(
        _ write: ([Int32], [UnsafePointer<CChar>?], [Bool], [UnsafePointer<CChar>?], [UnsafePointer<CChar>?], [Bool],
                  Int32) -> Void
    ) {
        WinUIStrings.withCStrings(titles) { titles in
            WinUIStrings.withCStrings(identifiers) { identifiers in
                WinUIStrings.withCStrings(icons.map(WinUIStrings.lines)) { icons in
                    write(kinds, titles, enabled, identifiers, icons, destructive, Int32(kinds.count))
                }
            }
        }
    }

    /// The relay's kinds: an item 0, a separator 1, a submenu opening 2 and closing 3.
    private mutating func add(_ entries: [MenuEntry]) {
        for entry in entries {
            switch entry.kind {
            case .item:
                append(0, entry.title, entry.isEnabled, entry.identifier,
                       icon: entry.icon.map(PictureArithmetic.files(for:)) ?? [], destructive: entry.isDestructive)
                actions.append { [weak element = entry.element] in element?.winUI.send(.clicked, []) }
            case .separator:
                append(1, "", true, nil)
            case .submenu:
                append(2, entry.title, entry.isEnabled, entry.identifier)
                add(entry.entries)
                append(3, "", true, nil)
            }
        }
    }

    private mutating func append(
        _ kind: Int32, _ title: String, _ isEnabled: Bool, _ identifier: String?, icon: [String] = [],
        destructive isDestructive: Bool = false
    ) {
        kinds.append(kind)
        titles.append(title)
        enabled.append(isEnabled)
        identifiers.append(identifier ?? "")
        icons.append(icon)
        destructive.append(isDestructive)
    }
}
