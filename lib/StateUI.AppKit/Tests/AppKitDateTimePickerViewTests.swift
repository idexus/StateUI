// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
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
    func testProgramWriteIsSilentAndReaderChangeReportsNativeLanesOnce() {
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
}

#endif
