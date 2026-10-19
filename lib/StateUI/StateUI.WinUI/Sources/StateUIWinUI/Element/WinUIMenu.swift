// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

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
    /// Each entry's shortcut; nil for none.
    private(set) var shortcuts: [KeyboardShortcut?] = []
    private(set) var actions: [() -> Void] = []

    /// The entries `container` holds, as the host layer walks them; none for no container.
    init(_ container: WinUIElement? = nil) {
        if let container { add(MenuEntry.entries(of: container.element)) }
    }

    /// The menus of a menu bar, as the host layer composes them.
    init(menus: [MenuEntry]) {
        add(menus)
    }

    /// `entries`, as the host layer walks them: a button's menu.
    init(entries: [MenuEntry]) {
        add(entries)
    }

    /// Whether the menu has no entries.
    var isEmpty: Bool { kinds.isEmpty }

    /// Whether the menu draws as `other` does: the same entries, captions, choosable ones, pictures and marks.
    func draws(like other: WinUIMenu) -> Bool {
        kinds == other.kinds && titles == other.titles && enabled == other.enabled && identifiers == other.identifiers
            && icons == other.icons && destructive == other.destructive && shortcuts == other.shortcuts
    }

    /// Hands `write` the entries as the relay takes them: their kinds, captions, whether each can be chosen, the
    /// identifiers, the files each picture may stand in, whether each destroys something, each shortcut's key - 0 for
    /// none - and modifiers and whether it gives way to typing, and how many there are.
    func relayed(
        _ write: ([Int32], [UnsafePointer<CChar>?], [Bool], [UnsafePointer<CChar>?], [UnsafePointer<CChar>?], [Bool],
                  [Int32], [Int32], [Bool], Int32) -> Void
    ) {
        let spelled = shortcuts.map { $0.flatMap(WinUIKeys.spelled) ?? (key: 0, modifiers: 0) }
        let givesWay = shortcuts.map { $0.map(KeyboardShortcuts.givesWayToTyping) ?? false }
        WinUIStrings.withCStrings(titles) { titles in
            WinUIStrings.withCStrings(identifiers) { identifiers in
                WinUIStrings.withCStrings(icons.map(WinUIStrings.lines)) { icons in
                    write(kinds, titles, enabled, identifiers, icons, destructive, spelled.map(\.key),
                          spelled.map(\.modifiers), givesWay, Int32(kinds.count))
                }
            }
        }
    }

    /// Each entry as the relay takes it, flat (`StateUIMenuEntry`).
    private mutating func add(_ entries: [MenuEntry]) {
        for entry in entries {
            switch entry.kind {
            case .item:
                append(entry.isOn.map { $0 ? .itemOn : .itemOff } ?? .item, entry.title, entry.isEnabled, entry.identifier,
                       icon: WinUIPictures.lines(entry.icon), destructive: entry.isDestructive,
                       shortcut: entry.keyboardShortcut)
                actions.append { [weak element = entry.element] in element?.winUI.choose() }
            case .separator:
                append(.separator, "", true, nil)
            case .submenu:
                append(.menuOpening, entry.title, entry.isEnabled, entry.identifier)
                add(entry.entries)
                append(.menuClosing, "", true, nil)
            }
        }
    }

    private mutating func append(
        _ kind: StateUIMenuEntry, _ title: String, _ isEnabled: Bool, _ identifier: String?, icon: [String] = [],
        destructive isDestructive: Bool = false, shortcut: KeyboardShortcut? = nil
    ) {
        kinds.append(kind.rawValue)
        titles.append(title)
        enabled.append(isEnabled)
        identifiers.append(identifier ?? "")
        icons.append(icon)
        destructive.append(isDestructive)
        shortcuts.append(shortcut)
    }
}
