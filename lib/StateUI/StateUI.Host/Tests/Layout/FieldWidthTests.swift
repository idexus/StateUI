// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
import XCTest

/// A field nothing sizes asks for twenty digits and its placeholder, the platform's own width standing where wider.
final class FieldWidthTests: XCTestCase {
    func testAFieldIsAtLeastAsWideAsTwentyDigitsAndItsPlaceholder() {
        XCTAssertEqual(
            FieldWidth.leastWords(placeholder: "Search every note"), [String(repeating: "0", count: 20), "Search every note"])
    }

    func testAFieldWithNoPlaceholderIsAtLeastTwentyDigitsWide() {
        XCTAssertEqual(FieldWidth.leastWords(placeholder: nil), [String(repeating: "0", count: 20)])
        XCTAssertEqual(FieldWidth.leastWords(placeholder: ""), [String(repeating: "0", count: 20)])
    }

    func testThePlatformsOwnWidthStandsWhereItIsWider() {
        XCTAssertEqual(FieldWidth.width(own: 150, measured: [120], chrome: 12), 150)
        XCTAssertEqual(FieldWidth.width(own: 2, measured: [120], chrome: 12), 132)
        XCTAssertEqual(FieldWidth.width(own: nil, measured: [100, 140], chrome: 0), 140)
    }
}
