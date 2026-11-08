// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// Numbers, days, times and lists as each language and region writes them: the exact text, the same on every host.
@MainActor
final class FormattingTests: XCTestCase {
    private let day = CalendarDate(year: 2026, month: 9, day: 30)

    private func localization(_ language: TestLanguage, _ formats: LocaleTag) -> Localization<TestCatalog> {
        Localization(TestCatalog.self, language: language, formatLocale: formats)
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
        XCTAssertEqual(english.number(1.125, fractionDigits: 2), "1.13", "a tie rounds away from zero")
        XCTAssertEqual(english.number(-1.125, fractionDigits: 2), "-1.13")
    }

    /// A number of any size is written in full from the digits Swift writes for it - the shortest that read back
    /// as the same number - grouped, with the digits asked for after the point: a whole number too large for an
    /// `Int`, the largest there is, and one too small to show its digits alike; only infinity and not-a-number
    /// keep Swift's own spelling.
    func testANumberOfAnySizeIsWrittenInFull() {
        let english = localization(.english, "en-US"), polish = localization(.polish, "pl-PL")
        let whole = 1_000_000_000_000_000

        XCTAssertEqual(english.number(Double(whole), fractionDigits: 2), english.number(whole) + ".00")
        XCTAssertEqual(english.number(-Double(whole), fractionDigits: 2), english.number(-whole) + ".00")
        XCTAssertEqual(english.number(1e15 + 0.5), "1,000,000,000,000,000.5")
        XCTAssertEqual(english.number(1e20, fractionDigits: 2), "100,000,000,000,000,000,000.00")
        XCTAssertEqual(polish.number(-1e20, fractionDigits: 0), "-100\u{A0}000\u{A0}000\u{A0}000\u{A0}000\u{A0}000\u{A0}000")
        XCTAssertEqual(english.number(1e23), "100,000,000,000,000,000,000,000", "the digits Swift writes, not the binary value's")

        let largest = english.number(Double.greatestFiniteMagnitude, fractionDigits: 99)
        XCTAssertTrue(largest.hasPrefix("179,769,313,486,231,570,000,"), largest)
        XCTAssertTrue(largest.hasSuffix(",000.000000000"), "nine digits at most after the point")
        XCTAssertEqual(largest.filter(\.isNumber).count, 309 + 9)

        XCTAssertEqual(english.number(1.5e-7), "0")
        XCTAssertEqual(english.number(1.5e-7, fractionDigits: 7), "0.0000002")
        XCTAssertEqual(english.number(-1.5e-7, fractionDigits: 2), "0.00", "no minus before nothing")
        for value in [Double.infinity, -Double.infinity, Double.nan] {
            XCTAssertEqual(english.number(value, fractionDigits: 2), String(value))
        }
    }

    func testDays() {
        let english = localization(.english, "en-US"), polish = localization(.polish, "pl-PL")

        XCTAssertEqual(english.date(day, format: .long), "September 30, 2026")
        XCTAssertEqual(english.date(day, format: .medium), "Sep 30, 2026")
        XCTAssertEqual(english.date(day, format: .short), "9/30/26")
        XCTAssertEqual(polish.date(day, format: .long), "30 września 2026", "a month in a date is in the genitive")
        XCTAssertEqual(polish.date(day, format: .medium), "30 wrz 2026")
        XCTAssertEqual(polish.date(day, format: .short), "30.09.2026")
        XCTAssertEqual(english.date(day), "9/30/26", "a day is short unless said, as a time is")
        XCTAssertEqual(english.context.date(day), "9/30/26")
    }

    func testWordsFollowTheLanguageAndTheOrderFollowsTheFormats() {
        let english = localization(.english, "pl-PL")

        XCTAssertEqual(english.date(day, format: .long), "30 September 2026")
        XCTAssertEqual(english.number(12_345.5), "12\u{A0}345,5")
        XCTAssertEqual(english.list(["Ania", "Basia", "Celina"]), "Ania, Basia, and Celina")
    }

    func testALanguageWhoseGrammarFixesTheOrderKeepsIt() {
        let polish = localization(.polish, "en-US")

        XCTAssertEqual(polish.date(day, format: .long), "30 września 2026", "a genitive month follows its day")
        XCTAssertEqual(polish.date(day, format: .medium), "30 wrz 2026")
        XCTAssertEqual(polish.date(day, format: .short), "9/30/26", "digits follow the region")
    }

    func testTimesOfDay() {
        let english = localization(.english, "en-US"), polish = localization(.polish, "pl-PL")
        let morning = ClockTime(hour: 7, minute: 30), evening = ClockTime(hour: 19, minute: 5)

        XCTAssertEqual(english.time(morning), "7:30\u{202F}AM")
        XCTAssertEqual(english.time(evening), "7:05\u{202F}PM")
        XCTAssertEqual(english.time(ClockTime(hour: 0, minute: 15)), "12:15\u{202F}AM")
        XCTAssertEqual(polish.time(morning), "07:30")
        XCTAssertEqual(polish.time(evening), "19:05")
        XCTAssertEqual(english.time(ClockTime(hour: 19, minute: 5, second: 7), format: .medium), "7:05:07\u{202F}PM")
        XCTAssertEqual(polish.time(ClockTime(hour: 7, minute: 30, second: 0), format: .medium), "07:30:00")
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
            language: "en-US", timeZone: "America/New_York", uses24HourClock: true,
            firstDayOfWeek: .sunday, isMetric: false, writingDirection: .leftToRight))
        defer {
            HostBoundary.setLocaleInfo(HostLocaleInfo(
                language: nil, timeZone: nil, uses24HourClock: false, firstDayOfWeek: .sunday,
                isMetric: true, writingDirection: .leftToRight))
        }

        XCTAssertEqual(Localization(TestCatalog.self).time(ClockTime(hour: 7, minute: 30)), "07:30")
    }
}
