// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A day and a time a picker holds, and who opened what it shows, the same on every host.
final class PickerRulesTests: XCTestCase {
    /// A day that is not in the calendar is refused; one past the range stands at its end; the ends stand in order.
    func testADayStandsInTheCalendarAndInItsRange() {
        let day = { (year: Int, month: Int, day: Int) in CalendarDate(year: year, month: month, day: day) }
        XCTAssertNil(CalendarArithmetic.held(day(2026, 2, 31), earliest: nil, latest: nil), "February 31st")
        XCTAssertNil(CalendarArithmetic.held(day(2026, 13, 1), earliest: nil, latest: nil), "a thirteenth month")
        XCTAssertNil(CalendarArithmetic.held(day(2026, 2, 29), earliest: nil, latest: nil), "no leap year")
        XCTAssertEqual(CalendarArithmetic.held(day(2024, 2, 29), earliest: nil, latest: nil), day(2024, 2, 29))
        XCTAssertNil(CalendarArithmetic.held(day(1900, 2, 29), earliest: nil, latest: nil), "a century")
        XCTAssertEqual(CalendarArithmetic.held(day(2000, 2, 29), earliest: nil, latest: nil), day(2000, 2, 29))

        let june = day(2026, 6, 1), october = day(2026, 10, 1)
        XCTAssertEqual(CalendarArithmetic.held(day(2026, 1, 5), earliest: june, latest: october), june)
        XCTAssertEqual(CalendarArithmetic.held(day(2026, 12, 5), earliest: june, latest: october), october)
        XCTAssertEqual(CalendarArithmetic.held(day(2026, 9, 25), earliest: october, latest: june), day(2026, 9, 25))
        XCTAssertTrue(CalendarArithmetic.range(october, june) == (june, october))
        XCTAssertTrue(CalendarArithmetic.range(nil, june) == (nil, june))
        XCTAssertTrue(CalendarArithmetic.range(day(2026, 2, 30), june) == (nil, june), "an end not in the calendar")
    }

    /// A time is added up from midnight and stands within the day: past it from the next one, before it from the
    /// last.
    func testATimeStandsWithinTheDay() {
        XCTAssertEqual(CalendarArithmetic.clock(ClockTime(hour: 7, minute: 30)), ClockTime(hour: 7, minute: 30))
        XCTAssertEqual(CalendarArithmetic.clock(ClockTime(hour: 25, minute: 99)), ClockTime(hour: 2, minute: 39))
        XCTAssertEqual(
            CalendarArithmetic.clock(ClockTime(hour: 0, minute: 0, second: -1)), ClockTime(hour: 23, minute: 59, second: 59))
        XCTAssertEqual(CalendarArithmetic.clock(ClockTime(hour: 24, minute: 0, millisecond: 500)), ClockTime(hour: 0, minute: 0))
    }

    /// A time of any size stands within the day: its parts add up without overflowing.
    func testATimeOfAnySizeStandsWithinTheDay() {
        XCTAssertEqual(
            CalendarArithmetic.clock(ClockTime(hour: .max, minute: .max, second: .max)),
            ClockTime(hour: 16, minute: 37, second: 7))
        XCTAssertEqual(
            CalendarArithmetic.clock(ClockTime(hour: .min, minute: .min, second: .min)),
            ClockTime(hour: 6, minute: 21, second: 52))
    }

    /// What the program opens or closes is heard by nobody; what the user does is, the closing of what the program
    /// opened included.
    func testOnlyTheUsersOpeningAndClosingAreHeard() {
        var opening = PickerOpening()
        XCTAssertTrue(opening.heard(open: true), "the user opens")
        XCTAssertTrue(opening.heard(open: false), "the user closes")

        XCTAssertTrue(opening.programAsks(open: true, shown: false), "the program opens")
        XCTAssertFalse(opening.heard(open: true), "heard by nobody")
        XCTAssertTrue(opening.heard(open: false), "the user closes what the program opened")

        XCTAssertFalse(opening.programAsks(open: false, shown: false), "nothing to close")
        XCTAssertTrue(opening.heard(open: true), "so the user's opening is heard")
        XCTAssertTrue(opening.programAsks(open: false, shown: true), "the program closes")
        XCTAssertFalse(opening.heard(open: false), "heard by nobody")
    }
}
