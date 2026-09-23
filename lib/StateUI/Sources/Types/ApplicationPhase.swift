// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where the application stands - in front, showing behind another
/// application, or out of sight. The host derives it from native application
/// and window events.
public enum ApplicationPhase: Int32, Sendable {
    /// One of its windows is the one in use.
    case active = 0

    /// Its windows are showing, and another application is in front.
    case inactive = 1

    /// None of its windows can be seen - it is hidden, or in the background.
    case background = 2
}
