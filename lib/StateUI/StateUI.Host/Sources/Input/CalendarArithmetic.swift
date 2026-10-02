// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// The day and the time a picker holds, the same on every host: a day not in the Gregorian calendar refused, one
/// past the range held at its end, and a time added up from midnight around the day.
/// Design: docs/design/host/runtime.md#a-day-and-a-time
@_spi(Host) public enum CalendarArithmetic {
    /// Whether `day` stands in the Gregorian calendar.
    public static func exists(_ day: CalendarDate) -> Bool {
        (1...12).contains(day.month) && (1...days(inMonth: day.month, of: day.year)).contains(day.day)
    }

    /// The range between `earliest` and `latest`, the earlier first whichever the tree gave first; an end not in
    /// the calendar stands nowhere.
    public static func range(
        _ earliest: CalendarDate?, _ latest: CalendarDate?
    ) -> (earliest: CalendarDate?, latest: CalendarDate?) {
        let first = earliest.flatMap { exists($0) ? $0 : nil }, last = latest.flatMap { exists($0) ? $0 : nil }
        guard let first, let last, last < first else { return (first, last) }
        return (last, first)
    }

    /// The day a picker shows for `day`: nil where it is not in the calendar - the picker keeps the day it shows -
    /// else within the range, past an end at that end.
    public static func held(_ day: CalendarDate, earliest: CalendarDate?, latest: CalendarDate?) -> CalendarDate? {
        guard exists(day) else { return nil }
        let (first, last) = range(earliest, latest)
        if let first, day < first { return first }
        if let last, day > last { return last }
        return day
    }

    /// The time of day `time` reaches, its hours, minutes and seconds added up from midnight: past the day from the
    /// next one's start, before it from the last one's end; no milliseconds.
    public static func clock(_ time: ClockTime) -> ClockTime {
        let day = 24 * 60 * 60
        // Each part taken within the day first, so no size overflows the sum.
        let seconds = (time.hour % 24 * 3_600 + time.minute % 1_440 * 60 + time.second % day) % day
        let within = (seconds + day) % day
        return ClockTime(hour: within / 3_600, minute: within % 3_600 / 60, second: within % 60)
    }

    /// How many days `month` of `year` has.
    public static func days(inMonth month: Int, of year: Int) -> Int {
        switch month {
        case 2: year % 4 == 0 && (year % 100 != 0 || year % 400 == 0) ? 29 : 28
        case 4, 6, 9, 11: 30
        default: 31
        }
    }
}
