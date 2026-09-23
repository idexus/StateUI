// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// The label on the keyboard's return key.
public enum ReturnKey: Int32, Sendable {
    /// Whatever the platform calls it.
    case `default` = 0

    /// "Done".
    case done = 1

    /// "Go".
    case go = 2

    /// "Next", for a field with another after it.
    case next = 3

    /// "Search".
    case search = 4

    /// "Send".
    case send = 5
}

extension ReturnKey: HostRepresentable {}
extension ReturnKey: StateChoice {}
