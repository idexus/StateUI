// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How a picker offers its values: a field opening a list, a row of segments,
/// or a radio button for each.
///
///     Picker(Span.allCases, selection: $span) { "\($0)" }
///         .presentation(.segmented)
public enum PickerPresentation: Int32, Sendable, CaseIterable {
    /// A field showing the chosen value, opening the list of all - the
    /// platform's own pop-up or drop-down.
    case menu = 0

    /// A row of segments, one for each value, the chosen one marked - for a
    /// few short values.
    case segmented = 1

    /// A radio button for each value, the chosen one on - every value in
    /// sight.
    case radio = 2
}

extension PickerPresentation: HostRepresentable {}
