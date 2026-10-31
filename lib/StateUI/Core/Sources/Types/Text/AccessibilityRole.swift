// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What kind of thing a screen reader says a view is - what `.accessibilityRole` takes, for a view composed of
/// parts that no control's own kind speaks for: a star rating drawn from pictures, a card that opens a page.
public enum AccessibilityRole: Int32, Sendable, CaseIterable {
    /// Something that acts when used; a reader offers to use it.
    case button = 1

    /// Something that stands on or off.
    case toggle = 2

    /// Something whose value goes up and down; a reader's swipe steps it.
    case adjustable = 3

    /// Something that takes the user somewhere.
    case link = 4

    /// A picture.
    case image = 5

    /// Words to read.
    case text = 6
}

extension AccessibilityRole: HostRepresentable {}
extension AccessibilityRole: StateChoice {}
