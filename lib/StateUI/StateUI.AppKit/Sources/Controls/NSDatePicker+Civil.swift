// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// A day and a time of day held by AppKit's field and stepper: an instant of the Gregorian calendar in the user's
/// zone - a day at its noon, a time on the calendar's first day - so no zone moves the user's value.
extension NSDatePicker {
    /// Dresses the picker as a field and stepper showing `elements` in the user's Gregorian calendar.
    func dressCivil(_ elements: NSDatePicker.ElementFlags) {
        var civil = Calendar(identifier: .gregorian)
        civil.locale = .current
        civil.timeZone = .current
        calendar = civil
        locale = .current
        timeZone = .current
        datePickerStyle = .textFieldAndStepper
        datePickerElements = elements
    }

    /// The instant `day` stands at; nil where the calendar holds no such day.
    func instant(of day: CalendarDate) -> Date? {
        guard let civil = calendar,
              let instant = civil.date(from: DateComponents(year: day.year, month: day.month, day: day.day, hour: 12))
        else { return nil }
        return self.day(of: instant) == day ? instant : nil
    }

    /// The instant `time` stands at, its hour and minute; the field shows no seconds.
    func instant(of time: ClockTime) -> Date? {
        calendar?.date(from: DateComponents(year: 2001, month: 1, day: 1, hour: time.hour, minute: time.minute))
    }

    /// The day `instant` falls on.
    func day(of instant: Date) -> CalendarDate {
        let parts = (calendar ?? .current).dateComponents([.year, .month, .day], from: instant)
        return CalendarDate(year: parts.year ?? 0, month: parts.month ?? 0, day: parts.day ?? 0)
    }

    /// The hour and minute `instant` shows.
    func time(of instant: Date) -> ClockTime {
        let parts = (calendar ?? .current).dateComponents([.hour, .minute], from: instant)
        return ClockTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }
}

#endif
