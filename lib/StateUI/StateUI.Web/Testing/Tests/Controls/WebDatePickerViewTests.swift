// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// A date field holds its day within the range, and writes itself only as the user leaves it.
@MainActor
final class WebDatePickerViewTests: XCTestCase {
    private let due = CalendarDate(year: 2026, month: 8, day: 2)
    private let last = CalendarDate(year: 2030, month: 12, day: 31)

    private func picker(telling told: @escaping (CalendarDate) -> Void) -> WebDatePickerView {
        let picker = WebDatePickerView()
        picker.onChosen = told
        picker.setRange(earliest: CalendarDate(year: 2020, month: 1, day: 1), latest: last)
        picker.setDate(due)
        return picker
    }

    /// A day typed past the range is told at its end, and the field shows that day once the user leaves it - not
    /// before, so a year typed digit by digit is not taken from under the user's keys.
    func testADayTypedPastTheRangeStandsAtItsEndOnceTheUserLeaves() {
        var told: [CalendarDate] = []
        let picker = picker { told.append($0) }
        defer { picker.detach() }

        WebPage.enter("2035-03-03", into: picker.node)
        XCTAssertEqual(told, [last])
        XCTAssertEqual(WebPage.value(of: picker.node), "2035-03-03")

        WebPage.leave(picker.node)
        XCTAssertEqual(WebPage.value(of: picker.node), last.text)
    }

    /// A field the user empties tells nothing and shows the day the picker holds once left.
    func testAFieldLeftEmptyShowsTheDayHeld() {
        var told: [CalendarDate] = []
        let picker = picker { told.append($0) }
        defer { picker.detach() }

        WebPage.enter("", into: picker.node)
        WebPage.leave(picker.node)

        XCTAssertEqual(told, [])
        XCTAssertEqual(WebPage.value(of: picker.node), due.text)
    }

    /// The day the tree writes back after the user's pick is the one shown already: the field is left alone.
    func testTheDayToldIsNotWrittenBack() {
        var told: [CalendarDate] = []
        let picker = picker { told.append($0) }
        defer { picker.detach() }

        WebPage.enter("2035-03-03", into: picker.node)
        picker.setDate(last)

        XCTAssertEqual(WebPage.value(of: picker.node), "2035-03-03")
    }
}

/// A time field writes its seconds, and steps by them, while its time has some.
@MainActor
final class WebTimePickerViewTests: XCTestCase {
    func testATimeWithSecondsStepsBySeconds() {
        var told: [ClockTime] = []
        let picker = WebTimePickerView()
        picker.onChosen = { told.append($0) }
        defer { picker.detach() }

        picker.setTime(ClockTime(hour: 7, minute: 30))
        XCTAssertEqual(WebPage.value(of: picker.node), "07:30")
        XCTAssertNil(WebPage.attribute(of: picker.node, "step"))

        WebPage.enter("06:45:30", into: picker.node)
        XCTAssertEqual(told, [ClockTime(hour: 6, minute: 45, second: 30)])
        XCTAssertEqual(WebPage.attribute(of: picker.node, "step"), "1", "a time the user typed steps as one written")
    }
}
