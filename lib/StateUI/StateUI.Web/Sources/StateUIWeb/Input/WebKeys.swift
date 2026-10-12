// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A keyboard shortcut as the page spells one: as the relay tells a key pressed - a key writing no character by
/// StateUI's number, a character by its code point, the keys held by their bits - and as `aria-keyshortcuts` names
/// it, Command on Apple's platforms and Control elsewhere for the platform's own key.
/// Design: docs/design/types/keyboard.md#on-each-platform
enum WebKeys {
    /// The shortcut a key pressed spells; nil for one naming no key.
    static func shortcut(named: Int32, character: Int32, held: Int32) -> KeyboardShortcut? {
        let key: Key
        if let known = NamedKey(rawValue: named) {
            key = Key(known)
        } else if character > 0, let scalar = UnicodeScalar(UInt32(character)) {
            key = Key(Character(scalar))
        } else {
            return nil
        }
        return KeyboardShortcut(key, modifiers: KeyModifiers(rawValue: held))
    }

    /// The shortcut as `aria-keyshortcuts` names it - `Control+Shift+S`.
    static func spelled(_ shortcut: KeyboardShortcut, onApple: Bool) -> String {
        var parts: [String] = []
        if shortcut.modifiers.contains(.primary) { parts.append(onApple ? "Meta" : "Control") }
        if shortcut.modifiers.contains(.alt) { parts.append("Alt") }
        if shortcut.modifiers.contains(.shift) { parts.append("Shift") }
        parts.append(shortcut.key.character.map { String($0).uppercased() } ?? shortcut.key.named.flatMap { names[$0] } ?? "")
        return parts.joined(separator: "+")
    }

    /// The shortcut as a menu shows it beside an entry's words - `⇧⌘S` on Apple's platforms, `Ctrl+Shift+S` elsewhere.
    static func shown(_ shortcut: KeyboardShortcut, onApple: Bool) -> String {
        let key = shortcut.key.character.map { String($0).uppercased() } ?? shortcut.key.named.flatMap { names[$0] } ?? ""
        if onApple {
            return (shortcut.modifiers.contains(.alt) ? "⌥" : "") + (shortcut.modifiers.contains(.shift) ? "⇧" : "")
                + (shortcut.modifiers.contains(.primary) ? "⌘" : "") + key
        }
        var parts: [String] = []
        if shortcut.modifiers.contains(.primary) { parts.append("Ctrl") }
        if shortcut.modifiers.contains(.alt) { parts.append("Alt") }
        if shortcut.modifiers.contains(.shift) { parts.append("Shift") }
        return (parts + [key]).joined(separator: "+")
    }

    /// The shortcut `aria-keyshortcuts` names; nil for words naming none.
    static func shortcut(spelled: String, onApple: Bool) -> KeyboardShortcut? {
        var held: KeyModifiers = []
        var key: Key?
        for part in spelled.split(separator: "+").map(String.init) {
            switch part {
            case onApple ? "Meta" : "Control": held.insert(.primary)
            case "Alt": held.insert(.alt)
            case "Shift": held.insert(.shift)
            default: key = names.first { $0.value == part }.map { Key($0.key) } ?? part.first.map { Key($0) }
            }
        }
        return key.map { KeyboardShortcut($0, modifiers: held) }
    }

    /// The page's names of the keys writing no character.
    static let names: [NamedKey: String] = [
        .return: "Enter", .escape: "Escape", .delete: "Backspace", .upArrow: "ArrowUp", .downArrow: "ArrowDown",
        .leftArrow: "ArrowLeft", .rightArrow: "ArrowRight", .f1: "F1", .f2: "F2", .f3: "F3", .f4: "F4", .f5: "F5",
        .f6: "F6", .f7: "F7", .f8: "F8", .f9: "F9", .f10: "F10", .f11: "F11", .f12: "F12",
    ]
}
