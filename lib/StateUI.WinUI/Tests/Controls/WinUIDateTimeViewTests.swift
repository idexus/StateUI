// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import StateUIHostConformance
import XCTest

/// A day and a time the user picks, a program's buttons writing them too and opening the calendar.
private struct DayPage: ContentView {
    let heard: Received<String>
    @State private var due = CalendarDate(year: 2026, month: 9, day: 25)
    @State private var alarm = ClockTime(hour: 7, minute: 30)
    @State private var showing = false

    var content: any View {
        let heard = heard
        return VStack {
            DatePicker($due)
                .isOpen(showing)
                .onDateChanged { heard.values.append("day \($0.day)") }
                .onOpened { heard.values.append("opened") }
                .onClosed {
                    heard.values.append("closed")
                    showing = false
                }
            TimePicker($alarm).onTimeChanged { heard.values.append("time \($0.hour):\($0.minute)") }
            Button("New Year").onClicked {
                due = CalendarDate(year: 2027, month: 1, day: 1)
                alarm = ClockTime(hour: 0, minute: 0)
            }
            Button("Open").onClicked { showing = true }
        }
    }
}

final class WinUIDateTimeViewTests: XCTestCase {
    /// The user's day and time are heard once and reach the states; the program's are shown and heard by nobody.
    func testTheUsersDayAndTimeAreHeardAndTheProgramsAreNot() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running { DayPage(heard: heard) }
            let day = try XCTUnwrap(host.views(WinUIDatePickerView.self).first)
            let time = try XCTUnwrap(host.views(WinUITimePickerView.self).first)
            XCTAssertEqual(day.date, CalendarDate(year: 2026, month: 9, day: 25))
            XCTAssertEqual(time.time, ClockTime(hour: 7, minute: 30))

            stateui_winui_date_pick_as_user(day.handle, 2026, 10, 3)
            stateui_winui_time_pick_as_user(time.handle, 8, 15)
            host.settle { heard.values.count == 2 }
            XCTAssertEqual(heard.values, ["day 3", "time 8:15"])

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { day.date == CalendarDate(year: 2027, month: 1, day: 1) }
            XCTAssertEqual(day.date, CalendarDate(year: 2027, month: 1, day: 1))
            XCTAssertEqual(time.time, ClockTime(hour: 0, minute: 0))
            XCTAssertEqual(heard.values, ["day 3", "time 8:15"], "the program's day and time heard by nobody")
        }
    }

    /// The calendar the program opens is not heard opening; the user closing it is heard.
    func testTheCalendarTheProgramOpensIsHeardOnlyAsTheUserClosesIt() throws {
        try onUIThread {
            let heard = Received<String>()
            let host = WinUIRenderer.running { DayPage(heard: heard) }
            let day = try XCTUnwrap(host.views(WinUIDatePickerView.self).first)

            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            host.settle { day.isOpen }
            XCTAssertTrue(day.isOpen)
            XCTAssertEqual(heard.values, [])

            stateui_winui_date_set_open(day.handle, false)
            host.settle { heard.values == ["closed"] }
            XCTAssertEqual(heard.values, ["closed"])
        }
    }
}
