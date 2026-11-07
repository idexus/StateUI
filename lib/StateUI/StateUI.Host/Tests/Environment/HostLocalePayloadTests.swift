// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
import XCTest

@MainActor
final class HostLocalePayloadTests: XCTestCase {
    func testOneFullTagAndZoneCarryTheLocaleAndItsOrderedPreferences() throws {
        let locale = try XCTUnwrap(HostLocaleInfo(words: [
            "SR_latn_rs", "Europe/Belgrade", "1", "1.000000", "1", "0", "ES_419", "en-GB",
        ]))

        XCTAssertEqual(locale.language, "sr-Latn-RS")
        XCTAssertEqual(locale.language?.script, "Latn")
        XCTAssertEqual(locale.language?.region, "RS")
        XCTAssertEqual(locale.timeZone, "Europe/Belgrade")
        XCTAssertEqual(locale.languages, ["es-419", "en-GB"])
        XCTAssertEqual(locale.languages.first?.region, "419")
        XCTAssertTrue(locale.uses24HourClock)
        XCTAssertEqual(locale.firstDayOfWeek, .monday)
        XCTAssertTrue(locale.isMetric)
        XCTAssertEqual(locale.writingDirection, .leftToRight)
    }

    func testUnavailableFieldsAreAbsentAndInvalidTagsRemainAvailable() throws {
        let absent = try XCTUnwrap(HostLocaleInfo(words: ["", "", "0", "0", "1", "0"]))
        XCTAssertNil(absent.language)
        XCTAssertNil(absent.timeZone)
        XCTAssertEqual(absent.languages, [])

        let invalid = try XCTUnwrap(HostLocaleInfo(words: ["not??", "", "0", "0", "1", "0", "not??", ""]))
        XCTAssertEqual(invalid.language, "not??")
        XCTAssertEqual(invalid.language?.isValid, false)
        XCTAssertEqual(invalid.languages, ["not??"], "an empty entry is no language")
        XCTAssertNil(invalid.timeZone)
        XCTAssertNil(HostLocaleInfo(words: ["en-GB", "Europe/London", "1", "1", "1"]))
    }

    func testWeekdayTextKeepsDecimalTruncationAndDefaultsForUnavailableNumbers() throws {
        let cases: [(String, Weekday)] = [
            ("1.000000", .monday), ("6.9", .saturday), ("nan", .sunday), ("inf", .sunday),
            ("1e100", .sunday), ("not a number", .sunday), ("7", .sunday), ("-1", .sunday),
        ]
        for (text, expected) in cases {
            let locale = try XCTUnwrap(HostLocaleInfo(words: ["es-419", "", "1", text, "1", "0"]))
            XCTAssertEqual(locale.firstDayOfWeek, expected, text)
        }
    }

    func testTypedValuesReachTheCoreWithoutReinterpretation() {
        let current = StandardEnvironment.locale
        let before = HostLocaleInfo(
            language: current.language, timeZone: current.timeZone, uses24HourClock: current.uses24HourClock,
            firstDayOfWeek: current.firstDayOfWeek, isMetric: current.isMetric,
            writingDirection: current.writingDirection, languages: current.languages)
        defer { HostBoundary.setLocaleInfo(before) }
        let invalid = LocaleTag("not??")
        let report = HostLocaleInfo(
            language: invalid, timeZone: nil, uses24HourClock: true, firstDayOfWeek: .saturday,
            isMetric: false, writingDirection: .rightToLeft, languages: ["sr-Latn-RS", invalid, ""])

        HostBoundary.setLocaleInfo(report)

        XCTAssertEqual(current.language, report.language)
        XCTAssertEqual(current.language?.isValid, false)
        XCTAssertNil(current.timeZone)
        XCTAssertEqual(current.languages, report.languages)
        XCTAssertEqual(current.uses24HourClock, report.uses24HourClock)
        XCTAssertEqual(current.firstDayOfWeek, report.firstDayOfWeek)
        XCTAssertEqual(current.isMetric, report.isMetric)
        XCTAssertEqual(current.writingDirection, report.writingDirection)
    }
}
