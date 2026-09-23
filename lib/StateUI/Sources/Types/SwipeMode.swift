// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// What a swipe reveals: buttons to tap, or one act carried out by the swipe
/// itself.
public enum SwipeMode: Int32, Sendable {
    /// The items appear and wait to be tapped. The default.
    case reveal = 0

    /// A full swipe runs the first item, with no tap at all.
    case execute = 1
}

extension SwipeMode: HostRepresentable {}
