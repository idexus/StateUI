// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What the network can reach.
public enum NetworkAccess: Int32, Sendable {
    /// The host has not said.
    case unknown = 0

    /// No network at all.
    case none = 1

    /// The local network only, with no route out.
    case local = 2

    /// The internet is reachable through a portal or another constraint.
    case constrainedInternet = 3

    /// The internet is reachable.
    case internet = 4
}
