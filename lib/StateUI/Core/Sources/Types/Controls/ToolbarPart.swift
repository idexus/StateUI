// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// A part of a split view's one bar: over its sidebar or over its detail.
public enum ToolbarPart: Int32, Sendable {
    /// Over the sidebar's pages.
    case sidebar = 0

    /// Over the detail's pages.
    case detail = 1
}

extension ToolbarPart: HostRepresentable {}
