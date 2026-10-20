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

    /// No scene declares windows of the kind of this name.
    case undeclared(Name)

    /// The scene declares the kind of this name for another value - two kinds
    /// share the name, one of them with a value of another type, or none.
    case wrongValue(Name)

    /// The platform opens no second window - a phone, a page in a browser.
    case unsupported
}
