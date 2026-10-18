// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUIWeb
import XCTest

/// A number as CSS is given it: whole as it is, any other to a millionth, no nought trailing.
final class WebCSSNumberTests: XCTestCase {
    /// A WHOLE NUMBER IS WRITTEN AS IT IS.
    func testAWholeNumberIsWrittenAsItIs() {
        XCTAssertEqual(WebCSS.number(12), "12")
        XCTAssertEqual(WebCSS.number(-60), "-60")
        XCTAssertEqual(WebCSS.number(0), "0")
    }

    /// ANY OTHER IS WRITTEN TO A MILLIONTH, its trailing noughts left off, a rounding's error gone.
    func testAnyOtherIsWrittenToAMillionth() {
        XCTAssertEqual(WebCSS.number(0.1 + 0.2), "0.3")
        XCTAssertEqual(WebCSS.number(1.0 / 3), "0.333333")
        XCTAssertEqual(WebCSS.number(-0.5), "-0.5")
        XCTAssertEqual(WebCSS.number(-12.0625), "-12.0625")
        XCTAssertEqual(WebCSS.number(0.7071067811865476), "0.707107")
    }

    /// LESS THAN A HALF OF A MILLIONTH IS NOUGHT, never a minus nought.
    func testLessThanHalfAMillionthIsNought() {
        XCTAssertEqual(WebCSS.number(0.0000001), "0")
        XCTAssertEqual(WebCSS.number(-0.0000001), "0")
    }

    /// A NUMBER BEYOND ANY ROOM AND ONE THAT IS NONE are written as before: the first as Swift spells it, the second
    /// as nought.
    func testANumberBeyondAnyRoomAndOneThatIsNone() {
        XCTAssertEqual(WebCSS.number(.infinity), "0")
        XCTAssertEqual(WebCSS.number(.nan), "0")
        XCTAssertEqual(WebCSS.number(1.5e13), "15000000000000")
        XCTAssertEqual(WebCSS.number(1e20), String(1e20))
        XCTAssertEqual(WebCSS.number(1.5e13 + 0.25), String(1.5e13 + 0.25))
    }
}
