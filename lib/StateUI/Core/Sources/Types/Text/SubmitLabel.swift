// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// The label on the keyboard's return key.
public enum SubmitLabel: Int32, Sendable {
    /// Whatever the platform calls it: as the field is submitted, an
    /// on-screen keyboard goes down, as it does for Done.
    case automatic = 0

    /// "Done": as the field is submitted, an on-screen keyboard goes down.
    case done = 1

    /// "Go": as the field is submitted, an on-screen keyboard goes down.
    case go = 2

    /// "Next": as the field is submitted, the keyboard goes on to the next
    /// field its page reads - in the order the page is written, past a field
    /// hidden or disabled; after the last it stays.
    case next = 3

    /// "Search": as the field is submitted, an on-screen keyboard goes down.
    case search = 4

    /// "Send": the keyboard stays up for the next message as the field is
    /// submitted.
    case send = 5
}

extension SubmitLabel: HostRepresentable {}
extension SubmitLabel: StateChoice {}
