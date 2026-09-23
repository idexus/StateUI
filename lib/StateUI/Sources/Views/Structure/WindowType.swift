// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What kind of window a group opens - the name a scene declares one under,
/// and a session's `openWindow` opens one by.
///
///     extension WindowType {
///         static let fonts = WindowType("fonts")
///         static let document = WindowType("document")
///     }
///
/// The name is written down with every window the system may restore, so it
/// should not change between versions of the application.
public struct WindowType: Hashable, Sendable, CustomStringConvertible, HostRepresentable {
    /// The name - what is written down with a window of this kind.
    public let name: String

    /// A kind of window, by its name.
    ///
    /// - Parameter name: the application's own name for it.
    public init(_ name: String) {
        self.name = name
    }

    /// The name, so an interpolated diagnostic prints it plainly.
    public var description: String { name }

    /// The name, crossing as a `.name`.
    public var propValue: PropValue { .name(name) }

    /// A kind back from its name - nil for any other kind of value.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .name(let name) = propValue else { return nil }

        self.init(name)
    }

    /// The inspector that shows what every render costs and builds - see
    /// `DebugInspector`, which is its window.
    ///
    ///     WindowGroup(.debugInspector) { DebugInspector() }
    public static let debugInspector = WindowType("stateui.debugInspector")
}
