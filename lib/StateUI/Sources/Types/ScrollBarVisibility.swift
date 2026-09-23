// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// When the scroll bars are drawn - what `.verticalScrollBarVisibility` and
/// `.horizontalScrollBarVisibility` take.
public enum ScrollBarVisibility: Int32, Sendable {
    /// As the platform sees fit.
    case `default` = 0

    /// Always shown.
    case always = 1

    /// Never shown, though it still scrolls.
    case never = 2
}

extension ScrollBarVisibility: HostRepresentable {}
extension ScrollBarVisibility: StateChoice {}
