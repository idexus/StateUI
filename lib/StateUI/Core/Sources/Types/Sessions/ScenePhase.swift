// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Where a scene stands - in front, showing behind another, or out of sight.
public enum ScenePhase: Sendable {
    /// The scene is the one in front: one of its windows is the one in use.
    case active

    /// The scene is showing, and another is in front of it.
    case inactive

    /// Every window of the scene is out of sight, or the application is hidden
    /// or in the background.
    case background
}
