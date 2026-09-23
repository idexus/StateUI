// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How far the screen is rotated from its natural position.
public enum DisplayRotation: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// Not rotated.
    case rotation0 = 1

    /// A quarter turn.
    case rotation90 = 2

    /// Upside down.
    case rotation180 = 3

    /// Three quarters.
    case rotation270 = 4
}
