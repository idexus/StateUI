// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
import XCTest

final class GTKDatePickerViewTests: XCTestCase {
    /// GTK's calendar offers every day: one the user picks past the range lands at its end, on the calendar, the
    /// button and the state alike.
    func testADayPickedPastTheRangeStandsAtItsEnd() throws {
        try onUIThread {
            let due = State(wrappedValue: CalendarDate(year: 2026, month: 9, day: 25))
            let host = GTKRenderer.running {
                VStack {
                    DatePicker(due.projectedValue)
                        .minimumDate(CalendarDate(year: 2026, month: 9, day: 1))
                        .maximumDate(CalendarDate(year: 2026, month: 10, day: 31))
                }
            }
            let picker = try XCTUnwrap(host.views(GTKDatePickerView.self).first)
            let past = try XCTUnwrap(g_date_time_new_local(2026, 12, 24, 12, 0, 0))
            defer { g_date_time_unref(past) }

            gtk_calendar_select_day(picker.calendar.opaque, past)
            host.step()

            let end = CalendarDate(year: 2026, month: 10, day: 31)
            XCTAssertEqual(picker.date, end, "the calendar")
            XCTAssertEqual(due.wrappedValue, end, "the state")
            let words = String(cString: gtk_label_get_text(picker.label.opaque))
            XCTAssertTrue(words.contains("31"), "the button: \(words)")
        }
    }

    /// A day not in the calendar leaves the day shown.
    func testADayNotInTheCalendarLeavesTheDayShown() throws {
        try onUIThread {
            let due = State(wrappedValue: CalendarDate(year: 2026, month: 2, day: 27))
            let host = GTKRenderer.running { VStack { DatePicker(due.projectedValue) } }
            let picker = try XCTUnwrap(host.views(GTKDatePickerView.self).first)

            due.wrappedValue = CalendarDate(year: 2026, month: 2, day: 31)
            host.step()

            XCTAssertEqual(picker.date, CalendarDate(year: 2026, month: 2, day: 27))
        }
    }
}
