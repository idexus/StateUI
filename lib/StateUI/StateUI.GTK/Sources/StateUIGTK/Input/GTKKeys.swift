// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIGTK

/// A keyboard shortcut as GTK spells one: a key value - the character the key writes, or GDK's own for a key writing
/// none - and the modifier mask held with it, Control for the platform's own key.
/// Design: docs/design/types/keyboard.md#on-each-platform
enum GTKKeys {
    /// The key value and modifier mask of `shortcut`.
    static func spelled(_ shortcut: KeyboardShortcut) -> (keyval: guint, modifiers: GdkModifierType) {
        let keyval = shortcut.key.character.flatMap { $0.unicodeScalars.first }.map { gdk_unicode_to_keyval($0.value) }
            ?? shortcut.key.named.flatMap { named[$0] } ?? 0
        var mask: UInt32 = 0
        if shortcut.modifiers.contains(.primary) { mask |= GDK_CONTROL_MASK.rawValue }
        if shortcut.modifiers.contains(.shift) { mask |= GDK_SHIFT_MASK.rawValue }
        if shortcut.modifiers.contains(.alt) { mask |= GDK_ALT_MASK.rawValue }
        return (keyval, GdkModifierType(rawValue: mask))
    }

    /// The shortcut a key value and its mask spell; nil for a key StateUI names none of.
    static func shortcut(keyval: guint, modifiers: GdkModifierType) -> KeyboardShortcut? {
        let key: Key
        if let known = named.first(where: { $0.value == keyval })?.key {
            key = Key(known)
        } else if keyval == backTab {
            key = .tab
        } else if let scalar = UnicodeScalar(gdk_keyval_to_unicode(keyval)), scalar.value > 0 {
            key = Key(Character(scalar))
        } else {
            return nil
        }
        var held: KeyModifiers = []
        if modifiers.rawValue & GDK_CONTROL_MASK.rawValue != 0 { held.insert(.primary) }
        if modifiers.rawValue & GDK_SHIFT_MASK.rawValue != 0 { held.insert(.shift) }
        if modifiers.rawValue & GDK_ALT_MASK.rawValue != 0 { held.insert(.alt) }
        return KeyboardShortcut(key, modifiers: held)
    }

    /// Whether a field holding the keyboard in `widget`'s window is being typed into.
    @MainActor
    static func typing(in widget: GTKWidget) -> Bool {
        guard let root = gtk_widget_get_root(widget), let held = gtk_root_get_focus(root) else { return false }
        return types(into: held)
    }

    /// Whether `widget` is one the user types into: a text, a text view.
    static func types(into widget: GTKWidget) -> Bool {
        [gtk_text_get_type(), gtk_text_view_get_type()].contains {
            g_type_check_instance_is_a(widget.of(GTypeInstance.self), $0) != 0
        }
    }

    /// What GDK calls Tab held with Shift.
    private static let backTab: guint = 0xfe20

    /// GDK's key value for each key writing no character.
    private static let named: [NamedKey: guint] = [
        .return: 0xff0d, .escape: 0xff1b, .delete: 0xff08, .upArrow: 0xff52, .downArrow: 0xff54,
        .leftArrow: 0xff51, .rightArrow: 0xff53, .f1: 0xffbe, .f2: 0xffbf, .f3: 0xffc0, .f4: 0xffc1, .f5: 0xffc2,
        .f6: 0xffc3, .f7: 0xffc4, .f8: 0xffc5, .f9: 0xffc6, .f10: 0xffc7, .f11: 0xffc8, .f12: 0xffc9,
        .tab: 0xff09, .space: 0x20, .home: 0xff50, .end: 0xff57, .pageUp: 0xff55, .pageDown: 0xff56,
    ]
}
