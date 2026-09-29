// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where an item scrolled to stands in the view.
public enum ScrollAnchor: Int32, Sendable {
    /// At the start: the top of a list, the leading edge of a row.
    case start = 0

    /// In the middle.
    case center = 1

    /// At the end.
    case end = 2

    /// Wherever it moves least to be wholly in view - nowhere, where it is.
    case nearest = 3
}

extension ScrollAnchor: HostRepresentable {}
