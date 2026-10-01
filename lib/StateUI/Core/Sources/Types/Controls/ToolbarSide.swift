// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// The edge of a bar a group of actions stands at.
public enum ToolbarSide: Int32, Sendable {
    /// The edge a line of words ends at, where a platform puts a page's actions.
    case trailing = 0

    /// The edge a line of words starts from, beside the way back.
    case leading = 1
}

extension ToolbarSide: HostRepresentable {}
