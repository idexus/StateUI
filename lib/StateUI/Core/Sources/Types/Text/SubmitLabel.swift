// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// The label on the keyboard's return key.
public enum SubmitLabel: Int32, Sendable {
    /// Whatever the platform calls it.
    case `default` = 0

    /// "Done".
    case done = 1

    /// "Go".
    case go = 2

    /// "Next": as the field is submitted, the keyboard goes on to the next
    /// field its page reads - in the order the page is written, past a field
    /// hidden or disabled; after the last it stays.
    case next = 3

    /// "Search".
    case search = 4

    /// "Send".
    case send = 5
}

extension SubmitLabel: HostRepresentable {}
extension SubmitLabel: StateChoice {}
