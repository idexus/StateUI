// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Which way something runs: across or down - the way a hand moves a layout's parameters.
public enum Orientation: Int32, Equatable, Sendable {
    /// Across: sideways - for a hand, the parameters growing as it moves to the left.
    case horizontal = 0

    /// Down: up and down - for a hand, the parameters growing as it moves up.
    case vertical = 1
}

extension Orientation: HostRepresentable {}
