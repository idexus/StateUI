// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Why a window was not opened or closed - what the application's
/// `openWindow` and `closeWindow` throw, and a scene's or a window's
/// `close()`.
public enum WindowError: Error, Equatable, Sendable {
    /// It is open already: opening what is open is refused, and says so.
    case alreadyOpen

    /// It is not open.
    case notOpen

    /// The session is not an open scene's: the one a view outside every scene
    /// reads, or one whose scene has ended.
    case noScene

    /// No scene declares windows of this kind.
    case undeclared(WindowType)

    /// The group is declared for another value: it opens one window and was
    /// given a value, or opens one per value and was given none, or a value of
    /// another type.
    case wrongValue(WindowType)

    /// The platform opens no second window - a phone.
    case unsupported
}
