// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A key a view takes, pressed, and the keys held with it (`onKeyPressed`).
///
///     .onKeyPressed(.tab) { press in press.modifiers.contains(.shift) ? focusPrevious() : focusNext() }
public struct KeyPress: Hashable, Sendable {
    /// The key pressed.
    public let key: Key

    /// The keys held with it: Shift, where it was. A key held with the platform's own key or Alt is a shortcut's,
    /// so a view never hears one with either.
    public let modifiers: KeyModifiers

    /// `key` pressed with `modifiers` held.
    public init(_ key: Key, modifiers: KeyModifiers = []) {
        self.key = key
        self.modifiers = modifiers
    }
}
