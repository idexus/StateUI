// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// The way a language is written - what `locale.writingDirection` says, and
/// what a view left at `LayoutDirection.inherited` lays out in at the root.
public enum WritingDirection: Int32, Sendable, CaseIterable {
    /// Left to right.
    case leftToRight = 1

    /// Right to left.
    case rightToLeft = 2
}

extension WritingDirection: HostRepresentable {}
