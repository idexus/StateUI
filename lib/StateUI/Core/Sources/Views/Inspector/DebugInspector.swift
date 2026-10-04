// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The inspector in a window of its own, beside its scene's other windows.
///
///     Window(.debugInspector) { DebugInspector() }
///
/// A window of the scene that declares it, showing the renders that reached
/// that scene - opened by a docked inspector's "Open in a window", or by
/// `application.openWindow(.debugInspector)`. Where a scene declares none, or
/// the platform opens no second window, the inspector docks in a window of
/// the scene instead.
public struct DebugInspector: View {
    /// The scene it inspects - the one it is a window of.
    @Environment(\.scene) private var scene

    /// The inspector's window.
    public init() {}

    /// The inspector, for its scene.
    public var body: some View { InspectorPage(scene: scene.id) }
}
