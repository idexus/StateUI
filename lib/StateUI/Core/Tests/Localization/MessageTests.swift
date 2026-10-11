// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import StateUI

/// A message's grammar: which plural form each count takes in each language, and what a missing form does.
@MainActor
final class MessageTests: XCTestCase {
    /// Names the plural form a count takes, so a test reads the category itself.
    private let category = Message<Int> { count, context in
        context.plural(count, zero: "zero", one: "one", two: "two", few: "few", many: "many", other: "other")
    }

    private func forms(_ language: TestLanguage, _ counts: [Int]) -> [String] {
        let localization = Localization(TestCatalog.self, language: .fixed(language))
        return counts.map { localization.text(category, $0) }
    }

    func testPolishTakesOneFewAndMany() {
        XCTAssertEqual(
            forms(.polish, [0, 1, 2, 5, 12, 22, 112, 1234, 21, 101]),
            ["many", "one", "few", "many", "many", "few", "many", "few", "many", "many"],
            "112 ends in 12, so it is \"112 plików\"")
    }

    func testEnglishTakesOneAndOther() {
        XCTAssertEqual(forms(.english, [0, 1, 2, 21, 101]), ["other", "one", "other", "other", "other"])
    }

    func testAMissingFormSaysWhichAndFallsBackToOther() {
        let polish = Localization(TestCatalog.self, language: .fixed(.polish))
        let unfinished = Message<Int> { count, context in
            context.plural(count, one: "\(count) plik", other: "\(count) pliku")
        }

        XCTAssertEqual(polish.text(unfinished, 2), "2 pliku")
        XCTAssertTrue(hasComplained("needs its \"few\" form for 2"))
    }

    func testAnInsertedTextIsIsolatedFromTheSentencesDirection() {
        let localization = Localization(TestCatalog.self)
        let opened = Message<String> { name, context in "Opened \(context.isolated(name))" }

        XCTAssertEqual(localization.text(opened, "Plan.pdf"), "Opened \u{2068}Plan.pdf\u{2069}")
    }
}
