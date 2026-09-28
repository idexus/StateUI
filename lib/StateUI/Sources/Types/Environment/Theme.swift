// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Which look the system asked for.
public enum Theme: Int32, Sendable {
    /// The system did not say.
    case system = 0

    /// Light.
    case light = 1

    /// Dark.
    case dark = 2
}
