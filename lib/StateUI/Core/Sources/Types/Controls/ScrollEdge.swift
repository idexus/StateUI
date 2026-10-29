// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How what scrolls under a bar shows at the bar's edge - what `.bottomBar(edge:)` takes.
public enum ScrollEdge: Int32, Sendable {
    /// As the platform draws it.
    case automatic = 0

    /// Cut off at the bar on a blur, a line along it.
    case hard = 1

    /// Nothing: what scrolls under the bar shows as it is.
    case none = 2
}

extension ScrollEdge: HostRepresentable {}
