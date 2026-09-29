// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The inspector in a window of its own, beside its scene's main window.
///
///     WindowGroup(.debugInspector) { DebugInspector() }
///
/// A window of the scene that declares it, showing the renders that reached
/// that scene - opened by the ⓘ of any of the scene's pages, or by
/// `scene.openWindow(.debugInspector)`. Where a scene declares none, or the
/// platform opens no second window, the inspector docks in the main window
/// instead.
public struct DebugInspector: Window {
    /// The scene it inspects - the one it is a window of.
    @Environment private var scene: SceneSession

    /// The inspector's window.
    public init() {}

    /// The inspector, for its scene.
    public var page: any Page { InspectorPage(scene: scene.id) }
}
