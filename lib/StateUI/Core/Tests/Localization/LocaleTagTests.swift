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

    /// A tag is read as BCP 47 writes it, in ASCII letters and digits: a singleton with its parts after it, a
    /// private use alone, each part where it stands.
    func testATagIsReadAsBCP47WritesIt() {
        XCTAssertFalse(LocaleTag("en-x").isValid, "a singleton with nothing after it")
        XCTAssertFalse(LocaleTag("en-u").isValid)
        XCTAssertFalse(LocaleTag("żół-PL").isValid, "letters outside ASCII")
        XCTAssertFalse(LocaleTag("pl-٣٣٣").isValid, "digits outside ASCII")
        XCTAssertFalse(LocaleTag("pl-PL-Latn").isValid, "a script after the region")
        XCTAssertTrue(LocaleTag("x-private").isValid, "a private use alone")
        XCTAssertEqual(LocaleTag("X-Private").identifier, "x-private")
        XCTAssertEqual(LocaleTag("x-private").language, "", "which names no language")
        XCTAssertEqual(LocaleTag("en-us-u-ca-gregory").identifier, "en-US-u-ca-gregory", "an extension")
        XCTAssertEqual(LocaleTag("DE-ch-1996").identifier, "de-CH-1996", "a variant")
        XCTAssertEqual(LocaleTag("sl-rozaj-biske-x-mine").identifier, "sl-rozaj-biske-x-mine")
    }

    /// A variant or an extension's singleton stands once in a tag, a private use's parts as often as written; and the
    /// text is ASCII as written, before any case is changed - the Kelvin sign lowers to an ASCII `k`.
    func testATagSaysEachVariantAndSingletonOnceInASCII() {
        XCTAssertFalse(LocaleTag("de-DE-1901-1901").isValid, "a variant twice")
        XCTAssertFalse(LocaleTag("en-a-bbb-a-ccc").isValid, "a singleton twice")
        XCTAssertTrue(LocaleTag("en-a-bbb-b-ccc-x-a-a").isValid, "a private use's parts repeat")
        XCTAssertFalse(LocaleTag("\u{212A}K-PL").isValid, "the Kelvin sign")
    }

    /// An extended language stands between the language and its script and region, and leaves both read.
    func testAnExtendedLanguageKeepsItsScriptAndRegion() {
        let tag = LocaleTag("ZH-CMN-hant-tw")

        XCTAssertTrue(tag.isValid)
        XCTAssertEqual(tag.identifier, "zh-cmn-Hant-TW")
        XCTAssertEqual(tag.language, "zh")
        XCTAssertEqual(tag.script, "Hant")
        XCTAssertEqual(tag.region, "TW")
        XCTAssertEqual(tag.likelyScript, "Hant")
    }

    func testAScriptLeftUnsaidIsTheOneItsLanguageIsWrittenIn() {
        XCTAssertEqual(LocaleTag("sr").likelyScript, "Cyrl")
        XCTAssertEqual(LocaleTag("zh-TW").likelyScript, "Hant")
        XCTAssertEqual(LocaleTag("zh").likelyScript, "Hans")
        XCTAssertEqual(LocaleTag("pl").likelyScript, "Latn")
        XCTAssertEqual(LocaleTag("sr-Latn").likelyScript, "Latn", "a script said wins")
    }

    func testRightToLeftScriptsAreKnown() {
        XCTAssertEqual(LocaleTag("ar").writingDirection, .rightToLeft)
        XCTAssertEqual(LocaleTag("he-IL").writingDirection, .rightToLeft)
        XCTAssertEqual(LocaleTag("pl").writingDirection, .leftToRight)
        XCTAssertEqual(LocaleTag("pa-Arab").writingDirection, .rightToLeft, "a script said decides")
    }
}
