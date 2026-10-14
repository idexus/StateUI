// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@testable import StateUI

/// A language tag as StateUI reads it: its parts, its standard spelling, and whether it is one at all.
final class LocaleTagTests: XCTestCase {
    func testATagIsReadIntoItsParts() {
        let tag: LocaleTag = "sr-Latn-RS"

        XCTAssertEqual(tag.language, "sr")
        XCTAssertEqual(tag.script, "Latn")
        XCTAssertEqual(tag.region, "RS")
        XCTAssertTrue(tag.isValid)
    }

    func testATagIsKeptInItsStandardSpelling() {
        XCTAssertEqual(LocaleTag("PL_pl").identifier, "pl-PL")
        XCTAssertEqual(LocaleTag("zh-hant-tw").identifier, "zh-Hant-TW")
        XCTAssertEqual(LocaleTag("pl_PL.UTF-8@euro").identifier, "pl-PL", "a POSIX locale names its language and region")
        XCTAssertEqual(LocaleTag("es-419").region, "419")
    }

    func testTextThatIsNoTagSaysSo() {
        XCTAssertFalse(LocaleTag("").isValid)
        XCTAssertFalse(LocaleTag("polish").isValid)
        XCTAssertFalse(LocaleTag("pl-PL-").isValid)
        XCTAssertEqual(LocaleTag("polish").identifier, "polish", "what is no tag is kept as written")
    }

    func testAScriptLeftUnsaidIsTheOneItsLanguageIsWrittenIn() {
        XCTAssertEqual(LocaleTag("sr").likelyScript, "Cyrl")
        XCTAssertEqual(LocaleTag("zh-TW").likelyScript, "Hant")
        XCTAssertEqual(LocaleTag("zh").likelyScript, "Hans")
        XCTAssertEqual(LocaleTag("pl").likelyScript, "Latn")
        XCTAssertEqual(LocaleTag("sr-Latn").likelyScript, "Latn", "a script said wins")
    }

    func testRightToLeftScriptsAreKnown() {
        XCTAssertEqual(LocaleTag("ar").direction, .rightToLeft)
        XCTAssertEqual(LocaleTag("he-IL").direction, .rightToLeft)
        XCTAssertEqual(LocaleTag("pl").direction, .leftToRight)
        XCTAssertEqual(LocaleTag("pa-Arab").direction, .rightToLeft, "a script said decides")
    }
}
