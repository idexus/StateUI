// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A flag set, its bits numbered by StateUI: append a flag, never insert one.
// Design: docs/design/types/keyboard.md#modifiers

/// The keys held with a shortcut's key.
///
///     Button("Save As").keyboardShortcut("s", modifiers: [.primary, .shift])
public struct KeyModifiers: OptionSet, Hashable, Sendable {
    /// The flag bits.
    public let rawValue: Int32

    /// From the raw bits. `.primary` and `[.primary, .shift]` are the
    /// ordinary way in.
    public init(rawValue: Int32) {
        self.rawValue = rawValue
    }

    /// The platform's own key for a shortcut: Command on Apple's platforms,
    /// Control elsewhere.
    public static let primary = KeyModifiers(rawValue: 1 << 0)

    /// Shift.
    public static let shift = KeyModifiers(rawValue: 1 << 1)

    /// Option on Apple's platforms, Alt elsewhere.
    public static let alt = KeyModifiers(rawValue: 1 << 2)
}

extension KeyModifiers: HostRepresentable {}
