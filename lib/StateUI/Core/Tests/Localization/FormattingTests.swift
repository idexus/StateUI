// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// Numbers, days, times and lists as each language and region writes them: the exact text, the same on every host.
@MainActor
final class FormattingTests: XCTestCase {
    private let day = CalendarDate(year: 2026, month: 9, day: 30)

    private func localization(_ language: TestLanguage, _ formats: LocaleTag) -> Localization<TestCatalog> {
        Localization(TestCatalog.self, language: .fixed(language), formatLocale: .fixed(formats))
    }

    func testWholeNumbers() {
        let english = localization(.english, "en-US"), polish = localization(.polish, "pl-PL")

        XCTAssertEqual([1234, 12_345, -1_234_567, 0].map(english.number), ["1,234", "12,345", "-1,234,567", "0"])
        XCTAssertEqual(
            [1234, 12_345, -1_234_567, 0].map(polish.number), ["1234", "12\u{A0}345", "-1\u{A0}234\u{A0}567", "0"],
            "Polish groups only from five digits")
    }

    func testFractions() {
        let english = localization(.english, "en-US"), polish = localization(.polish, "pl-PL")

        XCTAssertEqual(english.number(12_345.5), "12,345.5")
        XCTAssertEqual(polish.number(12_345.5), "12\u{A0}345,5")
        XCTAssertEqual(english.number(0.125, fractionDigits: 2), "0.13")
        XCTAssertEqual(polish.number(2, fractionDigits: 2), "2,00")
        XCTAssertEqual(english.percent(0.25), "25%")
        XCTAssertEqual(polish.percent(0.125, fractionDigits: 1), "12,5%")
        XCTAssertEqual(english.percent(0.125), "13%")
    }

    /// A large number with many digits after the point is written - its whole part and its fraction rounded apart,
    /// a fraction rounding up carrying into the whole - never a trap.
    func testALargeNumberWithManyFractionDigitsIsWritten() {
        let english = localization(.english, "en-US")

        XCTAssertEqual(english.number(1e13, fractionDigits: 6), "10,000,000,000,000.000000")
        XCTAssertEqual(english.number(12_000_000_000.5, fractionDigits: 9), "12,000,000,000.500000000")
        XCTAssertEqual(english.number(0.9996, fractionDigits: 3), "1.000")
        XCTAssertEqual(english.number(-2.5, fractionDigits: 0), "-3")
    }

    func testDays() {
        let english = localization(.english, "en-US"), polish = localization(.polish, "pl-PL")

        XCTAssertEqual(english.date(day, style: .long), "September 30, 2026")
        XCTAssertEqual(english.date(day, style: .medium), "Sep 30, 2026")
        XCTAssertEqual(english.date(day, style: .short), "9/30/26")
        XCTAssertEqual(polish.date(day, style: .long), "30 września 2026", "a month in a date is in the genitive")
        XCTAssertEqual(polish.date(day, style: .medium), "30 wrz 2026")
        XCTAssertEqual(polish.date(day, style: .short), "30.09.2026")
    }

    func testWordsFollowTheLanguageAndTheOrderFollowsTheFormats() {
        let english = localization(.english, "pl-PL")

        XCTAssertEqual(english.date(day, style: .long), "30 September 2026")
        XCTAssertEqual(english.number(12_345.5), "12\u{A0}345,5")
        XCTAssertEqual(english.list(["Ania", "Basia", "Celina"]), "Ania, Basia, and Celina")
    }

    func testALanguageWhoseGrammarFixesTheOrderKeepsIt() {
        let polish = localization(.polish, "en-US")

        XCTAssertEqual(polish.date(day, style: .long), "30 września 2026", "a genitive month follows its day")
        XCTAssertEqual(polish.date(day, style: .medium), "30 wrz 2026")
        XCTAssertEqual(polish.date(day, style: .short), "9/30/26", "digits follow the region")
    }

    func testTimesOfDay() {
        let english = localization(.english, "en-US"), polish = localization(.polish, "pl-PL")
        let morning = ClockTime(hour: 7, minute: 30), evening = ClockTime(hour: 19, minute: 5)

        XCTAssertEqual(english.time(morning), "7:30\u{202F}AM")
        XCTAssertEqual(english.time(evening), "7:05\u{202F}PM")
        XCTAssertEqual(english.time(ClockTime(hour: 0, minute: 15)), "12:15\u{202F}AM")
        XCTAssertEqual(polish.time(morning), "07:30")
        XCTAssertEqual(polish.time(evening), "19:05")
    }

    func testLists() {
        let english = localization(.english, "en-US"), polish = localization(.polish, "pl-PL")

        XCTAssertEqual(english.list([]), "")
        XCTAssertEqual(english.list(["Ania"]), "Ania")
        XCTAssertEqual(english.list(["Ania", "Basia"]), "Ania and Basia")
        XCTAssertEqual(english.list(["Ania", "Basia", "Celina"]), "Ania, Basia, and Celina")
        XCTAssertEqual(polish.list(["Ania", "Basia", "Celina"]), "Ania, Basia i Celina")
    }

    func testTheSystemsClockDecidesWhereTheFormatsAreTheSystems() {
        HostBoundary.setLocaleInfo(HostLocaleInfo(
            language: "en", region: "US", name: "en-US", timeZone: "America/New_York", uses24HourClock: true,
            firstDayOfWeek: .sunday, isMetric: false, layoutDirection: .leftToRight))
        defer {
            HostBoundary.setLocaleInfo(HostLocaleInfo(
                language: "", region: "", name: "", timeZone: "", uses24HourClock: false, firstDayOfWeek: .sunday,
                isMetric: true, layoutDirection: .leftToRight))
        }

        XCTAssertEqual(Localization(TestCatalog.self).time(ClockTime(hour: 7, minute: 30)), "07:30")
    }
}
