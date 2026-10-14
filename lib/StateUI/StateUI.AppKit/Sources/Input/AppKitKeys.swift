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

    /// The shortcut a key equivalent and its flags spell; nil for no key.
    static func shortcut(key: String, modifiers: NSEvent.ModifierFlags) -> KeyboardShortcut? {
        guard let first = key.first, key.count == 1 else { return nil }
        let pressed = named.first { $0.value == first }.map { Key($0.key) } ?? Key(first)
        var held: KeyModifiers = []
        if modifiers.contains(.command) { held.insert(.primary) }
        if modifiers.contains(.shift) { held.insert(.shift) }
        if modifiers.contains(.option) { held.insert(.alt) }
        return KeyboardShortcut(pressed, modifiers: held)
    }

    /// The character AppKit's key equivalent names each key writing no character by.
    private static let named: [NamedKey: Character] = {
        func function(_ code: Int) -> Character { Character(UnicodeScalar(code)!) }
        var keys: [NamedKey: Character] = [
            .return: "\r", .escape: "\u{1b}", .delete: "\u{8}",
            .upArrow: function(NSUpArrowFunctionKey), .downArrow: function(NSDownArrowFunctionKey),
            .leftArrow: function(NSLeftArrowFunctionKey), .rightArrow: function(NSRightArrowFunctionKey),
        ]
        let functions: [NamedKey] = [.f1, .f2, .f3, .f4, .f5, .f6, .f7, .f8, .f9, .f10, .f11, .f12]
        for (offset, key) in functions.enumerated() { keys[key] = function(NSF1FunctionKey + offset) }
        return keys
    }()
}
#endif
