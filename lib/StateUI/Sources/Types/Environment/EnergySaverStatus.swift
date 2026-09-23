// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Whether the platform's battery saver is on.
public enum EnergySaverStatus: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// The saver is on, so the application can reduce optional work.
    case on = 1

    /// The saver is off.
    case off = 2
}
