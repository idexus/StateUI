// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How deep a heading is - what `.accessibilityHeadingLevel` takes.
///
/// A user who cannot see the page moves through it by its headings, and the
/// level is what tells them whether the next one starts a section or sits
/// inside the one they are in.
public enum HeadingLevel: Int32, Sendable {
    /// Ordinary content, however large it happens to be drawn. The default.
    case none = 0

    /// What the page itself is about - one of these, at the top.
    case level1 = 1

    /// A section of the page.
    case level2 = 2

    /// A part of a section.
    case level3 = 3

    /// A part of that.
    case level4 = 4

    /// Deeper again.
    case level5 = 5

    /// Deeper again.
    case level6 = 6

    /// Deeper again.
    case level7 = 7

    /// Deeper again.
    case level8 = 8

    /// The deepest a heading goes.
    case level9 = 9
}

extension HeadingLevel: HostRepresentable {}
extension HeadingLevel: StateChoice {}
