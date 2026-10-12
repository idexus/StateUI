// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a button stands for in its window beyond its caption: the action the window offers first, the way out, or an
/// action that destroys something. Each platform draws a role its own way, and the first two press from the keyboard.
public enum ButtonRole: Int32, Sendable, HostRepresentable {
    /// The window's main action: drawn with the platform's emphasis, and pressed by Return while no field being typed
    /// into takes the key.
    case primary = 0

    /// The way out without acting: pressed by Escape.
    case cancel = 1

    /// An action that destroys something: drawn in the platform's colour for one, where it has one.
    case destructive = 2
}
