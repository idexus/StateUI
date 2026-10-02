// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// How deep a heading is - what `.accessibilityHeading` takes.
///
/// A user who cannot see the page moves through it by its headings, and the
/// level is what tells them whether the next one starts a section or sits
/// inside the one they are in.
public enum AccessibilityHeadingLevel: Int32, Sendable {
    /// Ordinary content, however large it happens to be drawn. The default.
    case none = 0

    /// What the page itself is about - one of these, at the top.
    case h1 = 1

    /// A section of the page.
    case h2 = 2

    /// A part of a section.
    case h3 = 3

    /// A part of that.
    case h4 = 4

    /// Deeper again.
    case h5 = 5

    /// Deeper again.
    case h6 = 6

    /// Deeper again.
    case h7 = 7

    /// Deeper again.
    case h8 = 8

    /// The deepest a heading goes.
    case h9 = 9
}

extension AccessibilityHeadingLevel: HostRepresentable {}
extension AccessibilityHeadingLevel: StateChoice {}
