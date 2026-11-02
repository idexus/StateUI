// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where a session stands - the application's, a scene's or a window's: in front, showing behind another, or out of
/// sight. The host derives each from its native application and window events.
///
///     @Environment(\.window) private var window
///
///     Text("Notes").onChanged(window.phase, policy: .waitForPrevious) {
///         if window.phase == .background { try await save() }
///     }
public enum SessionPhase: Int32, Sendable {
    /// In front: the window in use, its scene, or the application holding it.
    case active = 0

    /// Showing, with another in front of it - another window, another scene, another application.
    case inactive = 1

    /// Out of sight: minimized, hidden, in the background, or going away - the place to save, as nothing promises
    /// the process comes back.
    case background = 2
}
