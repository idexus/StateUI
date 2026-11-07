// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

final class WebLocaleFactsTests: XCTestCase {
    func testBrowserWordsBecomeTypedTagsAndKeepTheirPreferences() throws {
        let locale = try XCTUnwrap(WebEnvironment.locale([
            "SR_latn_rs", "sr-Latn-RS", "Europe/Belgrade", "h23", "1", "ltr", "SR_latn_rs", "es-419",
        ]))

        XCTAssertEqual(locale.language, "sr-Latn-RS")
        XCTAssertEqual(locale.language?.script, "Latn")
        XCTAssertEqual(locale.timeZone, "Europe/Belgrade")
        XCTAssertEqual(locale.languages, ["sr-Latn-RS", "es-419"])
        XCTAssertTrue(locale.uses24HourClock)
        XCTAssertEqual(locale.firstDayOfWeek, .monday)
        XCTAssertTrue(locale.isMetric)
    }

    func testUnavailableAndInvalidBrowserFactsKeepTheirMeaning() throws {
        XCTAssertNil(WebEnvironment.locale([]))
        XCTAssertNil(WebEnvironment.locale(["", "", "", "", "", ""]))
        let invalid = try XCTUnwrap(WebEnvironment.locale(["not??", "not??", "", "", "", "rtl", "not??", ""]))
        XCTAssertEqual(invalid.language?.identifier, "not??")
        XCTAssertEqual(invalid.language?.isValid, false)
        XCTAssertNil(invalid.timeZone)
        XCTAssertEqual(invalid.languages, ["not??"], "an empty entry is no language")
        XCTAssertEqual(invalid.writingDirection, .rightToLeft)
        XCTAssertEqual(invalid.firstDayOfWeek, .sunday)
        XCTAssertFalse(invalid.uses24HourClock)

        let american = try XCTUnwrap(WebEnvironment.locale(["en", "en-Latn-US", "", "h12", "7", "ltr"]))
        XCTAssertEqual(american.language, "en")
        XCTAssertFalse(american.isMetric)
        XCTAssertEqual(american.firstDayOfWeek, .sunday)
    }
}
