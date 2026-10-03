// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One window of a kind, showing one view: beside the scene's main window, or - the first in a scene with no
/// `WindowGroup`, or written in the application's body - the main window of a scene of one session.
///
///     Window(.inspector) { Inspector() }
///
/// The window says what it is; the scene's session says when it opens:
///
///     @Environment private var scene: SceneSession
///
///     Button("Inspector").onClicked { try await scene.openWindow(.inspector) }
///
/// It belongs to its scene: it opens through the scene's session, closes with the scene, and the platform
/// restores it with its scene. As the main window of a scene of one session, the application's session opens
/// it - `try await application.openWindow(.preferences)` - once. A host without independent windows refuses
/// `openWindow` with `WindowError.unsupported`. Windows of a kind, one per value, are a
/// `WindowGroup(.kind, for:)`.
public struct Window<Role>: Scene {
    /// What it makes.
    var declared: DeclaredWindows

    /// None: the library's own scene.
    public var body: Never { return fatalError("a Window is the library's own scene: it has no body") }

    /// Offers an object to everything in the window, resolved by type the way `.environment` on a view is.
    public func environment<Value: AnyObject>(_ object: Value) -> Self {
        var copy = self
        copy.declared.environments.append((key: ObjectIdentifier(Value.self), object: object))
        return copy
    }
}

extension Window where Role == WindowRole.Beside {
    /// One window of `type`, showing `content`.
    ///
    /// - Parameters:
    ///   - type: what a session's `openWindow` opens it by.
    ///   - content: the view the window shows.
    public init<Content: View>(_ type: WindowType, @ViewBuilder content: @escaping () -> Content) {
        declared = DeclaredWindows(
            type: type, valueType: nil, kind: String(reflecting: Content.self),
            page: { _, _ in Node.page(content()) })
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

    /// Whether the window floats above the application's other windows - a tool that stays in sight over the main
    /// window it serves - while the application is in front. A host without native window levels leaves the order
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
