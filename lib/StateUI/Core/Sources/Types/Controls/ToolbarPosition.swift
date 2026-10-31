// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where on its bar an action stands: at one of its edges, or behind its overflow menu.
public enum ToolbarPosition: Int32, Sendable {
    /// The edge a line of words ends at, where a platform puts a page's actions.
    case end = 0

    /// The edge a line of words starts from, beside the way back.
    case start = 1

    /// Behind the bar's overflow menu.
    case overflow = 2
}

extension ToolbarPosition: HostRepresentable {}
