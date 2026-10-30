// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// The edge of a page whose bar a toolbar's items stand on - what `.toolbar(_:)` takes.
public enum ToolbarEdge: Int32, Sendable {
    /// The page's bar at its top: its title's.
    case top = 0

    /// A bar at the page's foot: a desktop's thin status bar, a phone's bottom toolbar.
    case bottom = 1
}

extension ToolbarEdge: HostRepresentable {}
