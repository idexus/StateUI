// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Which way something runs: across or down - the way a hand moves a value. It names the way alone: which way
/// along it a value grows is the interaction's (`Interaction.reversed(_:)`).
public enum Orientation: Int32, Equatable, Sendable {
    /// Across: sideways.
    case horizontal = 0

    /// Down: up and down.
    case vertical = 1
}

extension Orientation: HostRepresentable {}
