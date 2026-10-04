// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import StateUIConformance
import XCTest

final class AppKitDatePickerViewTests: XCTestCase {
    /// The range is AppKit's field's, and a day past it stands at its end.
    @MainActor
    func testADayPastTheRangeStandsAtItsEnd() {
        let picker = AppKitDatePickerView()

        picker.setRange(earliest: CalendarDate(year: 2020, month: 1, day: 1), latest: CalendarDate(year: 2026, month: 12, day: 31))
        picker.setDate(CalendarDate(year: 2027, month: 1, day: 1))

        XCTAssertEqual(picker.date, CalendarDate(year: 2026, month: 12, day: 31))
        XCTAssertEqual(picker.earliestForTesting, CalendarDate(year: 2020, month: 1, day: 1))
        XCTAssertEqual(picker.latestForTesting, CalendarDate(year: 2026, month: 12, day: 31))
        XCTAssertEqual(picker.datePickerElements, .yearMonthDay)
    }

    /// A range narrowed under the day shown moves the day within it.
    @MainActor
    func testARangeNarrowedMovesTheDayShownWithinIt() {
        let picker = AppKitDatePickerView()
        picker.setDate(CalendarDate(year: 2026, month: 9, day: 16))

        picker.setRange(earliest: nil, latest: CalendarDate(year: 2026, month: 6, day: 30))

        XCTAssertEqual(picker.date, CalendarDate(year: 2026, month: 6, day: 30))
    }

    /// A day not in the calendar leaves the day shown.
    @MainActor
    func testADayNotInTheCalendarLeavesTheDayShown() {
        let picker = AppKitDatePickerView()
        picker.setDate(CalendarDate(year: 2026, month: 2, day: 28))

        picker.setDate(CalendarDate(year: 2026, month: 2, day: 31))

        XCTAssertEqual(picker.date, CalendarDate(year: 2026, month: 2, day: 28))
    }

    /// The program's day is heard by nobody; the user's is told once.
    @MainActor
    func testTheProgramsDayIsSilentAndTheUsersToldOnce() {
        let picker = AppKitDatePickerView()
        var told: [CalendarDate] = []
        picker.onChosen = { told.append($0) }
        picker.setDate(CalendarDate(year: 2026, month: 8, day: 2))

        XCTAssertTrue(told.isEmpty)
        picker.chooseForTesting(CalendarDate(year: 2026, month: 9, day: 15))

        XCTAssertEqual(told, [CalendarDate(year: 2026, month: 9, day: 15)])
    }

    /// The day a user picks reaches the page's `onDateChanged`.
    @MainActor
    func testADayTheUserPicksReachesTheDateHandler() throws {
        let days = Received<CalendarDate>()
        let renderer = AppKitRenderer.running {
            DatePicker(CalendarDate(year: 2026, month: 8, day: 2))
                .onDateChanged { days.values.append($0) }
        }
        defer { renderer.closeForTesting() }
        let picker = try XCTUnwrap(renderer.nativeViews(AppKitDatePickerView.self).first)

        picker.chooseForTesting(CalendarDate(year: 2026, month: 9, day: 15))

        XCTAssertEqual(days.values, [CalendarDate(year: 2026, month: 9, day: 15)])
    }

    /// A date picker's earliest and latest day bound its native field, and the day it shows is held between them.
    @MainActor
    func testADatePickersRangeBoundsItsNativeField() throws {
        let renderer = AppKitRenderer.running {
            DatePicker(CalendarDate(year: 2027, month: 1, day: 1))
                .minimumDate(CalendarDate(year: 2020, month: 1, day: 1))
                .maximumDate(CalendarDate(year: 2026, month: 12, day: 31))
        }
        defer { renderer.closeForTesting() }
        let picker = try XCTUnwrap(renderer.nativeViews(AppKitDatePickerView.self).first)

        XCTAssertEqual(picker.earliestForTesting, CalendarDate(year: 2020, month: 1, day: 1))
        XCTAssertEqual(picker.latestForTesting, CalendarDate(year: 2026, month: 12, day: 31))
        XCTAssertEqual(picker.date, CalendarDate(year: 2026, month: 12, day: 31))
    }
}

#endif
