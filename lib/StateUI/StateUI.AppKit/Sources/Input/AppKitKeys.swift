// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// A keyboard shortcut as AppKit spells one: a key equivalent - the character the key writes, or the function key's
/// own - and the modifier flags held with it, Command for the platform's own key.
/// Design: docs/design/types/keyboard.md#on-each-platform
enum AppKitKeys {
    /// The key equivalent and modifier flags of `shortcut`.
    static func equivalent(of shortcut: KeyboardShortcut) -> (key: String, modifiers: NSEvent.ModifierFlags) {
        let key = shortcut.key.character.map { String($0) } ?? shortcut.key.named.flatMap { named[$0] }.map { String($0) } ?? ""
        var flags: NSEvent.ModifierFlags = []
        if shortcut.modifiers.contains(.primary) { flags.insert(.command) }
        if shortcut.modifiers.contains(.shift) { flags.insert(.shift) }
        if shortcut.modifiers.contains(.alt) { flags.insert(.option) }
        return (key, flags)
    }

    /// The characters a keyboard sends for `shortcut`'s key, which a key-down carries: Delete sends DEL, which no key
    /// equivalent is spelled with.
    static func typed(of shortcut: KeyboardShortcut) -> String {
        shortcut.key.named == .delete ? "\u{7f}" : equivalent(of: shortcut).key
    }

    /// The shortcut a key equivalent and its flags spell; nil for no key.
    static func shortcut(key: String, modifiers: NSEvent.ModifierFlags) -> KeyboardShortcut? {
        guard let first = key.first, key.count == 1 else { return nil }
        let pressed = (sent[first] ?? named.first { $0.value == first }?.key).map { Key($0) } ?? Key(first)
        var held: KeyModifiers = []
        if modifiers.contains(.command) { held.insert(.primary) }
        if modifiers.contains(.shift) { held.insert(.shift) }
        if modifiers.contains(.option) { held.insert(.alt) }
        return KeyboardShortcut(pressed, modifiers: held)
    }

    /// The characters a keyboard sends for keys a key equivalent names otherwise: Delete's DEL, the keypad Enter's ETX,
    /// Shift-Tab's back tab.
    private static let sent: [Character: NamedKey] = ["\u{7f}": .delete, "\u{3}": .return, "\u{19}": .tab]

    /// The character AppKit's key equivalent names each key writing no character by.
    private static let named: [NamedKey: Character] = {
        func function(_ code: Int) -> Character { Character(UnicodeScalar(code)!) }
        var keys: [NamedKey: Character] = [
            .return: "\r", .escape: "\u{1b}", .delete: "\u{8}",
            .upArrow: function(NSUpArrowFunctionKey), .downArrow: function(NSDownArrowFunctionKey),
            .leftArrow: function(NSLeftArrowFunctionKey), .rightArrow: function(NSRightArrowFunctionKey),
            .tab: "\t", .space: " ", .home: function(NSHomeFunctionKey), .end: function(NSEndFunctionKey),
            .pageUp: function(NSPageUpFunctionKey), .pageDown: function(NSPageDownFunctionKey),
        ]
        let functions: [NamedKey] = [.f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12]
        for (offset, key) in functions.enumerated() { keys[key] = function(NSF1FunctionKey + offset) }
        return keys
    }()
}
#endif
