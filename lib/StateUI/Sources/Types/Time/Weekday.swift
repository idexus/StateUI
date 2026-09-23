// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A closed vocabulary, numbered by StateUI: append a case, never insert one.
// Design: docs/design/types/vocabularies.md#written-out-and-appended

/// The first day of a calendar week reported by `LocaleInfo.firstDayOfWeek`.
public enum Weekday: Int32, Sendable {
    /// Sunday.
    case sunday = 0

    /// Monday.
    case monday = 1

    /// Tuesday.
    case tuesday = 2

    /// Wednesday.
    case wednesday = 3

    /// Thursday.
    case thursday = 4

    /// Friday.
    case friday = 5

    /// Saturday.
    case saturday = 6
}
