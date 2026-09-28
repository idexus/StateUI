// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// Where a view sits in the space its layout gives it - what
/// `.horizontalAlignment` and `.verticalAlignment` take.
public enum Alignment: Int32, Sendable {
    /// At the near edge - the left, or the top - taking only the room it needs.
    case start = 0

    /// In the middle, taking only the room it needs.
    case center = 1

    /// At the far edge, taking only the room it needs.
    case end = 2

    /// Taking all of it. The default.
    case fill = 3
}

extension Alignment: HostRepresentable {}
extension Alignment: StateChoice {}
