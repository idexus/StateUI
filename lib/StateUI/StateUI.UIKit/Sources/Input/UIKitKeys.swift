// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI

/// A keyboard shortcut as UIKit spells one: a key command's input - the character the key writes, or UIKit's name
/// for a key writing none - and the modifier flags held with it, Command for the platform's own key.
/// Design: docs/design/types/keyboard.md#on-each-platform
@MainActor
enum UIKitKeys {
    /// The key command pressing `shortcut`, running `action` on the responder that offers it.
    static func command(_ shortcut: KeyboardShortcut, action: Selector) -> UIKeyCommand {
        let spelled = spelling(of: shortcut)
        let command = UIKeyCommand(input: spelled.input, modifierFlags: spelled.flags, action: action)
        command.wantsPriorityOverSystemBehavior = true
        return command
    }

    /// A menu's entry stating `shortcut`, shown beside `title` as UIKit shows a key command's: `action` sent up the
    /// responder chain with `entry`, the number the entry is known by. It asks no priority over text: a key giving way
    /// to typing types into a field holding the keyboard.
    static func entry(
        _ shortcut: KeyboardShortcut, title: String, image: UIImage?, action: Selector, entry: UInt64
    ) -> UIKeyCommand {
        let spelled = spelling(of: shortcut)
        return UIKeyCommand(
            title: title, image: image, action: action, input: spelled.input, modifierFlags: spelled.flags,
            propertyList: NSNumber(value: entry))
    }

    /// The input and the modifier flags spelling `shortcut`.
    private static func spelling(of shortcut: KeyboardShortcut) -> (input: String, flags: UIKeyModifierFlags) {
        var flags: UIKeyModifierFlags = []
        if shortcut.modifiers.contains(.primary) { flags.insert(.command) }
        if shortcut.modifiers.contains(.shift) { flags.insert(.shift) }
        if shortcut.modifiers.contains(.alt) { flags.insert(.alternate) }
        return (shortcut.key.character.map { String($0) } ?? shortcut.key.named.flatMap { named[$0] } ?? "", flags)
    }

    /// The shortcut a key command presses; nil for an input naming no key StateUI knows.
    static func shortcut(of command: UIKeyCommand) -> KeyboardShortcut? {
        guard let input = command.input else { return nil }
        let key = named.first { $0.value == input }.map { Key($0.key) } ?? (input.count == 1 ? Key(input.first!) : nil)
        guard let key else { return nil }
        var held: KeyModifiers = []
        if command.modifierFlags.contains(.command) { held.insert(.primary) }
        if command.modifierFlags.contains(.shift) { held.insert(.shift) }
        if command.modifierFlags.contains(.alternate) { held.insert(.alt) }
        return KeyboardShortcut(key, modifiers: held)
    }

    /// UIKit's input for each key writing no character.
    private static let named: [NamedKey: String] = [
        .return: "\r", .escape: UIKeyCommand.inputEscape, .delete: UIKeyCommand.inputDelete,
        .upArrow: UIKeyCommand.inputUpArrow, .downArrow: UIKeyCommand.inputDownArrow,
        .leftArrow: UIKeyCommand.inputLeftArrow, .rightArrow: UIKeyCommand.inputRightArrow,
        .f1: UIKeyCommand.f1, .f2: UIKeyCommand.f2, .f3: UIKeyCommand.f3, .f4: UIKeyCommand.f4,
        .f5: UIKeyCommand.f5, .f6: UIKeyCommand.f6, .f7: UIKeyCommand.f7, .f8: UIKeyCommand.f8,
        .f9: UIKeyCommand.f9, .f10: UIKeyCommand.f10, .f11: UIKeyCommand.f11, .f12: UIKeyCommand.f12,
        .tab: "\t", .space: " ", .home: UIKeyCommand.inputHome, .end: UIKeyCommand.inputEnd,
        .pageUp: UIKeyCommand.inputPageUp, .pageDown: UIKeyCommand.inputPageDown,
    ]
}
#endif
