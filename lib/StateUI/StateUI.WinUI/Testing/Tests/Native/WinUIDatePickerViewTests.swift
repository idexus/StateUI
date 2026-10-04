// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

final class WinUIDatePickerViewTests: XCTestCase {
    /// The day a picker shows is the host layer's: one not in the calendar leaves the day shown, one past the range
    /// stands at its end.
    func testADayNotInTheCalendarIsRefusedAndOnePastTheRangeStandsAtItsEnd() throws {
        try onUIThread {
            let due = State(wrappedValue: CalendarDate(year: 2026, month: 2, day: 10))
            let host = WinUIRenderer.running {
                VStack { DatePicker(due.projectedValue).maximumDate(CalendarDate(year: 2026, month: 6, day: 30)) }
            }
            let picker = try XCTUnwrap(host.views(WinUIDatePickerView.self).first)

            due.wrappedValue = CalendarDate(year: 2026, month: 2, day: 31)
            for _ in 0..<10 { host.step() }
            XCTAssertEqual(picker.date, CalendarDate(year: 2026, month: 2, day: 10), "February 31st refused")

            due.wrappedValue = CalendarDate(year: 2026, month: 12, day: 24)
            host.settle { picker.date != CalendarDate(year: 2026, month: 2, day: 10) }
            XCTAssertEqual(picker.date, CalendarDate(year: 2026, month: 6, day: 30), "held at the latest day")
        }
    }

    /// The time a picker shows is added up from midnight around the day, as the host layer adds it.
    func testATimePastTheDayStandsInTheNext() throws {
        try onUIThread {
            let at = State(wrappedValue: ClockTime(hour: 9, minute: 0))
            let host = WinUIRenderer.running { VStack { TimePicker(at.projectedValue) } }
            let picker = try XCTUnwrap(host.views(WinUITimePickerView.self).first)

            at.wrappedValue = ClockTime(hour: 25, minute: 30)
            host.settle { picker.time != ClockTime(hour: 9, minute: 0) }
            XCTAssertEqual(picker.time, ClockTime(hour: 1, minute: 30))
        }
    }
}
