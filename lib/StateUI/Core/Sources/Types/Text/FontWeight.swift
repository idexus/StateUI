// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How heavy the strokes of the words are, from the lightest to the heaviest: the weights 400, 500, 600 and 700 of
/// the font.
///
///     Text("3 unread").fontWeight(.semibold)
public enum FontWeight: Int32, Sendable, CaseIterable {
    /// The font's ordinary weight.
    case regular = 0

    /// A step heavier than regular.
    case medium = 1

    /// Between medium and bold: emphasis that is not yet bold.
    case semibold = 2

    /// Bold.
    case bold = 3
}

extension FontWeight: HostRepresentable {}
extension FontWeight: StateChoice {}
