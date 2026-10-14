// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A keyboard shortcut as Android spells one: a key event's code - or the character it writes - and its meta state,
/// Control for the platform's own key.
/// Design: docs/design/types/keyboard.md#on-each-platform
enum AndroidKeys {
    /// `KeyEvent`'s meta bits: Shift, Alt and Control held.
    static let shift: Int32 = 0x1, alt: Int32 = 0x2, control: Int32 = 0x1000

    /// The shortcut a key pressed spells: its code, the character it writes with no modifier, and its meta state;
    /// nil for a key writing nothing StateUI names.
    static func shortcut(code: Int32, character: Int32, meta: Int32) -> KeyboardShortcut? {
        let key: Key
        if let named = named.first(where: { $0.value == code })?.key {
            key = Key(named)
        } else if character > 0, let scalar = UnicodeScalar(UInt32(character)) {
            key = Key(Character(scalar))
        } else {
            return nil
        }
        var held: KeyModifiers = []
        if meta & control != 0 { held.insert(.primary) }
        if meta & shift != 0 { held.insert(.shift) }
        if meta & alt != 0 { held.insert(.alt) }
        return KeyboardShortcut(key, modifiers: held)
    }

    /// The key code and meta state pressing `shortcut`; nil for a character no key of the letters and digits writes.
    static func pressed(_ shortcut: KeyboardShortcut) -> (code: Int32, meta: Int32)? {
        var meta: Int32 = 0
        if shortcut.modifiers.contains(.primary) { meta |= control }
        if shortcut.modifiers.contains(.shift) { meta |= shift }
        if shortcut.modifiers.contains(.alt) { meta |= alt }
        if let named = shortcut.key.named { return Self.named[named].map { ($0, meta) } }
        guard let scalar = shortcut.key.character?.unicodeScalars.first?.value else { return nil }
        switch scalar {
        case 0x61...0x7A: return (29 + Int32(scalar - 0x61), meta)
        case 0x30...0x39: return (7 + Int32(scalar - 0x30), meta)
        default: return nil
        }
    }

    /// `KeyEvent`'s code for each key writing no character.
    private static let named: [NamedKey: Int32] = [
        .return: 66, .escape: 111, .delete: 67, .upArrow: 19, .downArrow: 20, .leftArrow: 21, .rightArrow: 22,
        .f1: 131, .f2: 132, .f3: 133, .f4: 134, .f5: 135, .f6: 136, .f7: 137, .f8: 138, .f9: 139, .f10: 140,
        .f11: 141, .f12: 142,
    ]
}
