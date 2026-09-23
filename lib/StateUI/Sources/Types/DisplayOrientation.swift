// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Which way the screen is turned, coarsely.
public enum DisplayOrientation: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// Taller than wide.
    case portrait = 1

    /// Wider than tall.
    case landscape = 2
}
