// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI

/// A day and a time of day held by UIKit's compact picker: they belong to no zone, so the picker counts in the
/// Gregorian calendar at UTC and shows them there.
extension UIDatePicker {
    /// The Gregorian calendar at UTC.
    static let civil: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// Dresses the picker as UIKit's compact one in `mode`, counting in the civil calendar.
    func dressCivil(_ mode: UIDatePicker.Mode) {
        datePickerMode = mode
        preferredDatePickerStyle = .compact
        calendar = Self.civil
        timeZone = Self.civil.timeZone
    }

    /// The instant `day` stands at; nil where the calendar holds no such day.
    static func instant(of day: CalendarDate) -> Date? {
        guard let instant = civil.date(from: DateComponents(year: day.year, month: day.month, day: day.day)) else {
            return nil
        }
        return self.day(of: instant) == day ? instant : nil
    }

    /// The instant `time` stands at, its hour and minute.
    static func instant(of time: ClockTime) -> Date? {
        civil.date(from: DateComponents(year: 2000, month: 1, day: 1, hour: time.hour, minute: time.minute))
    }

    /// The day `instant` falls on.
    static func day(of instant: Date) -> CalendarDate {
        let parts = civil.dateComponents([.year, .month, .day], from: instant)
        return CalendarDate(year: parts.year ?? 0, month: parts.month ?? 1, day: parts.day ?? 1)
    }

    /// The hour and minute `instant` shows.
    static func time(of instant: Date) -> ClockTime {
        let parts = civil.dateComponents([.hour, .minute], from: instant)
        return ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}
#endif
