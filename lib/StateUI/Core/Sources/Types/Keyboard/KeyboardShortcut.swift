// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A key pressed with the keys held with it, which acts as the control it is
/// written on does when chosen.
///
///     MenuItem("Save").keyboardShortcut("s")
///
/// Crosses as its key - a character as text, another key by its number - and
/// its modifiers' bits.
public struct KeyboardShortcut: Hashable, Sendable, HostRepresentable, CustomStringConvertible {
    /// The key.
    public let key: Key

    /// The keys held with it.
    public let modifiers: KeyModifiers

    /// `key` pressed with `modifiers`.
    public init(_ key: Key, modifiers: KeyModifiers = .primary) {
        self.key = key
        self.modifiers = modifiers
    }

    /// The shortcut as it crosses.
    public var propValue: PropValue {
        let pressed: PropValue
        if let character = key.character {
            pressed = .string(String(character))
        } else {
            pressed = .enumeration(key.named?.rawValue ?? 0)
        }
        return .values([pressed, .enumeration(modifiers.rawValue)])
    }

    /// The shortcut back from what crossed.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, parts.count == 2, case .enumeration(let held) = parts[1] else {
            return nil
        }
        switch parts[0] {
        case .string(let text) where text.count == 1: key = Key(text.first!)
        case .enumeration(let number): guard let named = NamedKey(rawValue: number) else { return nil }; key = Key(named)
        default: return nil
        }
        modifiers = KeyModifiers(rawValue: held)
    }

    /// The shortcut as a message writes it: its modifiers, then its key - `primary+shift+s`.
    public var description: String {
        let held = [(KeyModifiers.primary, "primary"), (.shift, "shift"), (.alt, "alt")]
            .filter { modifiers.contains($0.0) }.map(\.1)
        let pressed = key.character.map { String($0) } ?? key.named.map { "\($0)" } ?? "?"
        return (held + [pressed]).joined(separator: "+")
    }
}
