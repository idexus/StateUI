// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How many of an `ItemsView`'s items the user can choose - which the type of
/// the binding given to `.selection` says.
public enum SelectionMode: Int32, Sendable {
    /// None: a tap only activates an item.
    case none = 0

    /// One at a time.
    case single = 1

    /// As many as the user likes.
    case multiple = 2
}

extension SelectionMode: HostRepresentable {}
