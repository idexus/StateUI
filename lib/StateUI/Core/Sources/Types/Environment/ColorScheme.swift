// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// A theme: light or dark, or the system's.
public enum ColorScheme: Int32, Sendable {
    /// The system's: what an application follows unless it holds a theme of
    /// its own, and what a host reports where the system did not say.
    case system = 0

    /// Light.
    case light = 1

    /// Dark.
    case dark = 2
}

extension ColorScheme: HostRepresentable {}
