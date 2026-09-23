// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Whether the text is drawn as written, or in one case throughout.
///
/// The letters the user sees change; the value behind them does not - a
/// `TextField` set to `.uppercase` still reports what was typed, so this is a
/// look rather than an edit.
public enum TextCase: Int32, Sendable {
    /// As written.
    case none = 0

    /// As the platform sees fit, which everywhere is as written.
    case `default` = 1

    /// all in lower case.
    case lowercase = 2

    /// ALL IN UPPER CASE - a heading, a button's caption.
    case uppercase = 3
}

extension TextCase: HostRepresentable {}
extension TextCase: StateChoice {}
