// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A day: a year, a month and a day of the month, and nothing else.
///
///     CalendarDate(year: 2026, month: 8, day: 2)
///
/// What a `DatePicker` shows and reports, and what its `.minimumDate` and
/// `.maximumDate` take. No time of day, no zone: `ClockTime` is the other half.
///
/// Design: docs/design/types/dates-and-time.md#without-foundation
public struct CalendarDate: Equatable, Hashable, Comparable, Sendable, HostRepresentable {
    /// The year, in full: 2026, not 26.
    public var year: Int

    /// The month, 1 to 12 - January is 1, not 0.
    public var month: Int

    /// The day of the month, from 1.
    public var day: Int

    /// A day. Nothing checks that it exists: a `DatePicker` given February
    /// 31st goes on showing the date it had.
    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Reads `2026-08-02` - year, month and day, hyphen-separated, with or
    /// without the leading zeros, and a minus before a year before the first.
    ///
    ///     guard let due = CalendarDate(row.dueDate) else { return }
    ///
    /// Nil for any other shape, so text that is not a date shows up at the
    /// point it is read instead of becoming a silent 0-0-0.
    public init?(_ text: String) {
        let before = text.hasPrefix("-")
        let parts = text.dropFirst(before ? 1 : 0).split(separator: "-", omittingEmptySubsequences: false)

        guard parts.count == 3,
              parts.allSatisfy({ part in !part.isEmpty && part.allSatisfy { ("0"..."9").contains($0) } }),
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }

        self.init(year: before ? -year : year, month: month, day: day)
    }

    /// The day back from the three numbers a picker reports - year, month,
    /// day, each the whole part of its number. Nil for anything else, so a
    /// report that does not read leaves the handler alone.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 3,
              let year = Int(exactly: numbers[0].rounded(.towardZero)),
              let month = Int(exactly: numbers[1].rounded(.towardZero)),
              let day = Int(exactly: numbers[2].rounded(.towardZero))
        else { return nil }

        self.init(year: year, month: month, day: day)
    }

    /// The same, for a payload's value that may be missing.
    init?(_ value: PropValue?) {
        guard let value else { return nil }
        self.init(propValue: value)
    }

    /// `2026-08-02` - the day as a line of text, for putting one in a label:
    /// `Label("Due \(due.text)")`. A year before the first is written with a
    /// minus, `-0005-03-01`, and reads back.
    ///
    /// One fixed shape, never a display format: a `DatePicker` writes a date
    /// for the user with `.format(…)`, against the user's locale.
    public var text: String {
        "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    /// Year, month and day as three numbers, the order a picker reports them.
    public var propValue: PropValue {
        .numbers([Double(year), Double(month), Double(day)])
    }

    /// Earlier than. Compares the three numbers in order, which is what makes a
    /// date range a matter of `<` rather than of a calendar.
    public static func < (left: CalendarDate, right: CalendarDate) -> Bool {
        (left.year, left.month, left.day) < (right.year, right.month, right.day)
    }

    /// Zero-padded by hand, without Foundation; a minus before the zeros.
    private func pad(_ value: Int, _ width: Int) -> String {
        var digits = String(value.magnitude)

        while digits.count < width {
            digits = "0" + digits
        }

        return value < 0 ? "-" + digits : digits
    }
}

extension CalendarDate: StateValue {
    /// Year, month and day as three lanes, in that order.
    public var carried: StateCarried { .lanes([Double(year), Double(month), Double(day)]) }

    /// A day from those three lanes. Nil for any other count, so a report that
    /// does not read leaves the state alone.
    public init?(carried: StateCarried) {
        guard case .lanes(let lanes) = carried, lanes.count == 3 else { return nil }

        self.init(year: Int(lanes[0].rounded()), month: Int(lanes[1].rounded()), day: Int(lanes[2].rounded()))
    }

    /// Three.
    public static var lanes: Int { 3 }
}
