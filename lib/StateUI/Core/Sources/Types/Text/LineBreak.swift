// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What text does when it will not fit on one line - wrap, or be cut short
/// with an ellipsis.
///
/// The truncating cases need the control to be BOUNDED to show anything: a
/// label free to grow never runs out of room, so nothing is ever cut.
public enum LineBreak: Int32, Sendable {
    /// One line, whatever it costs.
    case noWrap = 0

    /// Wraps at spaces. The default for a Label.
    case wordWrap = 1

    /// Wraps mid-word where a word does not fit.
    case characterWrap = 2

    /// One line, cut at the START, with an ellipsis there.
    case headTruncation = 3

    /// One line, cut at the END, with an ellipsis there.
    case tailTruncation = 4

    /// One line, cut in the MIDDLE - which keeps both ends readable, as a file
    /// path wants.
    case middleTruncation = 5
}

extension LineBreak: HostRepresentable {}
extension LineBreak: StateChoice {}
