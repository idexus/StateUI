// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitDateTimePickerViewTests: XCTestCase {
    @MainActor
    func testDateRangeIsAppliedBeforeTheCivilDayAndClampsIt() {
        let picker = AppKitDateTimePickerView(mode: .date)

        picker.apply(
            value: [2027, 1, 1],
            writeValue: true,
            minimum: [2020, 1, 1],
            maximum: [2026, 12, 31],
            font: .systemFont(ofSize: 14),
            textColor: .labelColor,
            enabled: false)

        XCTAssertEqual(picker.valueLanesForTesting, [2026, 12, 31])
        XCTAssertEqual(picker.minimumLanesForTesting, [2020, 1, 1])
        XCTAssertEqual(picker.maximumLanesForTesting, [2026, 12, 31])
        XCTAssertFalse(picker.isEnabled)
        XCTAssertEqual(picker.datePickerElements, .yearMonthDay)
    }

    @MainActor
    func testInvalidCivilDayDoesNotReplaceTheStandingNativeValue() {
        let picker = AppKitDateTimePickerView(mode: .date)
        picker.apply(
            value: [2026, 2, 28],
            writeValue: true,
            minimum: nil,
            maximum: nil,
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            enabled: true)

        picker.apply(
            value: [2026, 2, 31],
            writeValue: true,
            minimum: nil,
            maximum: nil,
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            enabled: true)

        XCTAssertEqual(picker.valueLanesForTesting, [2026, 2, 28])
    }

    @MainActor
    func testTimeIsAClockMinuteAndDoesNotKeepAnInvisibleSecond() {
        let picker = AppKitDateTimePickerView(mode: .time)
        picker.apply(
            value: [21, 5, 30],
            writeValue: true,
            minimum: nil,
            maximum: nil,
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            enabled: true)

        XCTAssertEqual(picker.valueLanesForTesting, [21, 5, 0])
        XCTAssertEqual(picker.datePickerElements, .hourMinute)
    }

    @MainActor
    func testProgramWriteIsSilentAndUserChangeReportsNativeLanesOnce() {
        let picker = AppKitDateTimePickerView(mode: .date)
        var reports: [[Double]] = []
        picker.onValueChanged = { reports.append($0) }
        picker.apply(
            value: [2026, 8, 2],
            writeValue: true,
            minimum: nil,
            maximum: nil,
            font: .systemFont(ofSize: 13),
            textColor: .labelColor,
            enabled: true)

        XCTAssertTrue(reports.isEmpty)
        picker.changeForTesting(to: [2026, 9, 15])

        XCTAssertEqual(reports, [[2026, 9, 15]])
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
        let picker = try XCTUnwrap(renderer.nativeViews(AppKitDateTimePickerView.self).first)

        picker.changeForTesting(to: [2026, 9, 15])

        XCTAssertEqual(days.values, [CalendarDate(year: 2026, month: 9, day: 15)])
    }

    /// The time a user picks reaches the page's `onTimeChanged`.
    @MainActor
    func testATimeTheUserPicksReachesTheTimeHandler() throws {
        let times = Received<ClockTime>()
        let renderer = AppKitRenderer.running {
            TimePicker(ClockTime(hour: 7, minute: 30))
                .onTimeChanged { times.values.append($0) }
        }
        defer { renderer.closeForTesting() }
        let picker = try XCTUnwrap(renderer.nativeViews(AppKitDateTimePickerView.self).first)

        picker.changeForTesting(to: [21, 5, 0])

        XCTAssertEqual(times.values, [ClockTime(hour: 21, minute: 5)])
    }

    /// A date picker's earliest and latest day bound its native calendar,
    /// and the day it shows is held between them.
    @MainActor
    func testADatePickersRangeBoundsItsNativeCalendar() throws {
        let renderer = AppKitRenderer.running {
            DatePicker(CalendarDate(year: 2027, month: 1, day: 1))
                .minimumDate(CalendarDate(year: 2020, month: 1, day: 1))
                .maximumDate(CalendarDate(year: 2026, month: 12, day: 31))
        }
        defer { renderer.closeForTesting() }
        let picker = try XCTUnwrap(renderer.nativeViews(AppKitDateTimePickerView.self).first)

        XCTAssertEqual(picker.minimumLanesForTesting, [2020, 1, 1])
        XCTAssertEqual(picker.maximumLanesForTesting, [2026, 12, 31])
        XCTAssertEqual(picker.valueLanesForTesting, [2026, 12, 31])
    }
}

#endif
