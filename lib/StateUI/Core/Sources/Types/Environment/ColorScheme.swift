// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// A theme: light or dark. The application holds one, or none to follow the
/// system's (`application.colorScheme`); the one in force is always one of the
/// two (`info.colorScheme`).
public enum ColorScheme: Int32, Sendable {
    /// Light.
    case light = 1

    /// Dark.
    case dark = 2
}

extension ColorScheme: HostRepresentable {}
