// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// A step of the platform's own type ramp, from the largest to the smallest: each platform gives its own size and
/// weight to each, and the size grows with the user's text size.
///
///     Text("Inbox").textStyle(.title)
///
/// A size or a weight the view gives itself stands over its style's.
public enum TextStyle: Int32, Sendable, CaseIterable {
    /// The largest words on a screen, a figure or a hero's line.
    case display = 0

    /// A page's or a window's title.
    case title = 1

    /// A section's title under the page's.
    case subtitle = 2

    /// Words standing out among the body's: the body's size, a heavier weight.
    case headline = 3

    /// Running text - what words stand in when they say no style.
    case body = 4

    /// A note beside or under other words: the smallest.
    case caption = 5
}

extension TextStyle: HostRepresentable {}
extension TextStyle: StateChoice {}
