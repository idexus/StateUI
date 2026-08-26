// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A date, without Foundation.

/// A day: a year, a month and a day of the month, and nothing else.
///
///     CalendarDate(year: 2026, month: 8, day: 2)
///
/// What a `DatePicker` shows and reports, and what its `.minimumDate` and
/// `.maximumDate` take. No time of day, no zone: `ClockTime` is the other half.
///
/// NOT Foundation's `Date`, and the difference is deliberate: turning one of
/// those into text needs a DateFormatter, DateFormatter needs ICU, and ICU is
/// what this library cannot have - it ships as separate DLLs on Windows and a
/// mismatched one takes the process down with nothing diagnosable. Three
/// integers need none of that.
///
/// It travels as those integers - year, month, day - which is also how it
/// comes BACK from a picker, so the two directions say the same thing and
/// nothing has to agree about which number is the month.
public struct CalendarDate: Equatable, Hashable, Comparable, Sendable {
    /// The year, in full: 2026, not 26.
    public var year: Int

    /// The month, 1 to 12 - January is 1, not 0.
    public var month: Int

    /// The day of the month, from 1.
    public var day: Int

    /// A day. Nothing checks that it exists: February 31st travels, and the
    /// host reads it as no day at all - which leaves the property UNSET, so a
    /// DatePicker goes on showing the date it already had, silently.
    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    /// Reads `2026-08-02` - year, month and day, hyphen-separated, with or
    /// without the leading zeros.
    ///
    ///     guard let due = CalendarDate(row.dueDate) else { return }
    ///
    /// Nil for any other shape, so text that is not a date shows up at the
    /// point it is read instead of becoming a silent 0-0-0.
    public init?(_ text: String) {
        let parts = text.split(separator: "-")

        guard parts.count == 3,
              let year = Int(parts[0]),
              let month = Int(parts[1]),
              let day = Int(parts[2])
        else {
            return nil
        }

        self.init(year: year, month: month, day: day)
    }

    /// Reads the three numbers a dateSelected payload carries - year, month,
    /// day. Nil for anything else, so a report that will not read leaves the
    /// handler alone.
    init?(_ value: PropValue?) {
        guard let numbers = value?.numbers, numbers.count == 3 else { return nil }
        self.init(year: Int(numbers[0]), month: Int(numbers[1]), day: Int(numbers[2]))
    }

    /// `2026-08-02` - the day as a line of text, for putting one in a label:
    /// `Label("Due \(due.text)")`.
    ///
    /// One fixed shape, never a display format: how a DatePicker WRITES a date
    /// for the reader is `.format(…)`, which the C# side does against the
    /// locale. This is for text an application composes itself.
    public var text: String {
        "\(pad(year, 4))-\(pad(month, 2))-\(pad(day, 2))"
    }

    /// Year, month, day - the same three a picker reports back, in the same
    /// order, so nothing is formatted going out and parsed coming in.
    var propValue: PropValue {
        .numbers([Double(year), Double(month), Double(day)])
    }

    /// Earlier than. Compares the three numbers in order, which is what makes a
    /// date range a matter of `<` rather than of a calendar.
    public static func < (left: CalendarDate, right: CalendarDate) -> Bool {
        (left.year, left.month, left.day) < (right.year, right.month, right.day)
    }

    /// Zero-padded by hand: String(format:) is Foundation, and Foundation is
    /// what this type exists to avoid.
    private func pad(_ value: Int, _ width: Int) -> String {
        var digits = String(value)

        while digits.count < width {
            digits = "0" + digits
        }

        return digits
    }
}
