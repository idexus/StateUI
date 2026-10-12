// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A keyboard shortcut as WinUI spells one: a virtual key and the virtual key modifiers held with it, Control for
/// the platform's own key. A character no letter's or digit's key writes has no virtual key of its own here.
/// Design: docs/design/types/keyboard.md#on-each-platform
enum WinUIKeys {
    /// `VirtualKeyModifiers`' bits: Control, Menu (Alt) and Shift.
    static let control: Int32 = 1, menu: Int32 = 2, shift: Int32 = 4

    /// The virtual key and modifiers of `shortcut`; nil for a character with no virtual key of its own.
    static func spelled(_ shortcut: KeyboardShortcut) -> (key: Int32, modifiers: Int32)? {
        var modifiers: Int32 = 0
        if shortcut.modifiers.contains(.primary) { modifiers |= control }
        if shortcut.modifiers.contains(.alt) { modifiers |= menu }
        if shortcut.modifiers.contains(.shift) { modifiers |= shift }
        if let named = shortcut.key.named { return Self.named[named].map { ($0, modifiers) } }
        guard let scalar = shortcut.key.character?.unicodeScalars.first?.value else { return nil }
        switch scalar {
        case 0x61...0x7A: return (Int32(scalar) - 0x20, modifiers)
        case 0x30...0x39: return (Int32(scalar), modifiers)
        default: return nil
        }
    }

    /// The shortcut a virtual key and its modifiers spell; nil for a key StateUI names none of.
    static func shortcut(key: Int32, modifiers: Int32) -> KeyboardShortcut? {
        let pressed: Key
        if let named = named.first(where: { $0.value == key })?.key {
            pressed = Key(named)
        } else if (0x41...0x5A).contains(key) || (0x30...0x39).contains(key),
                  let scalar = UnicodeScalar(UInt32(key)) {
            pressed = Key(Character(scalar))
        } else {
            return nil
        }
        var held: KeyModifiers = []
        if modifiers & control != 0 { held.insert(.primary) }
        if modifiers & menu != 0 { held.insert(.alt) }
        if modifiers & shift != 0 { held.insert(.shift) }
        return KeyboardShortcut(pressed, modifiers: held)
    }

    /// The virtual key of each key writing no character.
    private static let named: [NamedKey: Int32] = [
        .return: 13, .escape: 27, .delete: 8, .upArrow: 38, .downArrow: 40, .leftArrow: 37, .rightArrow: 39,
        .f1: 112, .f2: 113, .f3: 114, .f4: 115, .f5: 116, .f6: 117, .f7: 118, .f8: 119, .f9: 120, .f10: 121,
        .f11: 122, .f12: 123,
    ]
}
