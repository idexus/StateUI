// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What kind of window a group opens, and for what value - the name a scene declares one under, and a session's
/// `openWindow` opens one by.
///
///     extension WindowType where Value == Void {
///         static let fonts = WindowType("fonts")
///     }
///
///     extension WindowType where Value == UUID {
///         static let document = WindowType("document")
///     }
///
///     try await application.openWindow(.fonts)
///     try await application.openWindow(.document, value: id)
///
/// A kind of no value opens with none, and a kind of a value only with a value of its type: the compiler refuses
/// the other. The name is written down with every window the system may restore, so it should not change between
/// versions of the application.
public struct WindowType<Value>: Hashable, Sendable, CustomStringConvertible {
    /// The name - what is written down with a window of this kind.
    public var name: String { key.name }

    /// The name and the number the key is worked by (`KeyName`).
    let key: KeyName

    /// A kind of window, by its name.
    ///
    /// - Parameter name: the application's own name for it.
    public init(_ name: String) {
        key = KeyName(name)
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }
}

extension WindowType where Value == Void {
    /// The inspector that shows what every render costs and builds - see
    /// `DebugInspector`, which is its window.
    ///
    ///     Window(.debugInspector) { DebugInspector() }
    public static let debugInspector = WindowType("stateui.debugInspector")
}
