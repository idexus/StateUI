// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a scene stands - in front, showing behind another, or out of sight.
public enum ScenePhase: Sendable {
    /// The scene is the one in front: one of its windows is the one in use.
    case active

    /// The scene is showing, and another is in front of it.
    case inactive

    /// The scene's main window is stopped, or the application is hidden or in
    /// the background. Only the main window decides: a window the scene
    /// opened beside it does not.
    case background
}
