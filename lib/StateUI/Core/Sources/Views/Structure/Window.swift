// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One window of a kind in the scene that declares it, showing one view.
///
///     Window(.inspector) { Inspector() }
///
/// The window says what it is; the application's session says when it opens, opening its scene first where that
/// is not open:
///
///     @Environment private var application: ApplicationSession
///
///     Button("Inspector").onClicked { try await application.openWindow(.inspector) }
///
/// It opens once - `openWindow` answers `WindowError.alreadyOpen` while it is open - and the platform restores it
/// with its scene. A host without independent windows refuses `openWindow` with `WindowError.unsupported`. Windows
/// of a kind, one per value or as many as asked for, are a `WindowGroup`.
public struct Window: Scene {
    /// What it makes.
    var declared: DeclaredWindows

    /// None: the library's own scene.
    public var body: Never { return fatalError("a Window is the library's own scene: it has no body") }

    /// One window of `type`, showing `content`.
    ///
    /// - Parameters:
    ///   - type: what `ApplicationSession.openWindow` opens it by.
    ///   - content: the view the window shows.
    public init<Content: View>(_ type: WindowType, @ViewBuilder content: @escaping () -> Content) {
        declared = DeclaredWindows(
            type: type, valueType: nil, kind: String(reflecting: Content.self),
            page: { _, _ in Node.page(content()) }, single: true)
    }

    /// Offers an object to everything in the window, resolved by type the way `.environment` on a view is.
    public func environment<Value: AnyObject>(_ object: Value) -> Self {
        var copy = self
        copy.declared.environments.append((key: ObjectIdentifier(Value.self), object: object))
        return copy
    }

    /// Whether the window hides while another scene of the application is the one in front - and comes back when
    /// its own is. A host without that native policy leaves the window visible.
    ///
    ///     Window(.fonts) { FontsPanel() }
    ///         .hidesWhenInactive(true)
    public func hidesWhenInactive(_ hides: Bool) -> Self {
        var copy = self
        copy.declared.hides = hides
        return copy
    }

    /// Whether the window floats above the application's other windows - a tool that stays in sight over the
    /// windows it serves - while the application is in front. A host without native window levels leaves the order
    /// to the platform.
    ///
    ///     Window(.fonts) { FontsPanel() }
    ///         .floatsOnTop(true)
    public func floatsOnTop(_ floats: Bool) -> Self {
        var copy = self
        copy.declared.floats = floats
        return copy
    }
}
