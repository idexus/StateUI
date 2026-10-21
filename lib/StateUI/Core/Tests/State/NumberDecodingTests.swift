// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A number that no type holds - not a number, infinite, or beyond an Int -
// comes back as nothing, or as the nearest a channel holds: a value kept on
// disk or read from the host never stops the application.

import XCTest
@_spi(Host) @testable import StateUI

@MainActor
final class NumberDecodingTests: XCTestCase {
    private let unheld: [Double] = [.nan, .infinity, -.infinity, 1e30, Double(Int.max)]

    /// A whole number past 2^53 crosses to the host rounded, a number holding every whole number exactly only up to
    /// there: said once, where it crosses.
    func testAWholeNumberPastTwoToTheFiftyThirdIsSaidAsItCrosses() {
        _ = (1 << 53).carried
        _ = (1 << 53).propValue
        XCTAssertFalse(hasComplained("past 2^53"), "2^53 itself crosses whole")

        _ = ((1 << 53) + 1).carried

        XCTAssertTrue(hasComplained("past 2^53"))
    }

    /// 2^53 IS MEASURED THE SAME WHATEVER AN INT'S WIDTH: on the Web an `Int` has 32 bits, none of them past 2^53,
    /// where shifting one 53 places measured nought and every whole number but nought was said past it.
    func testTwoToTheFiftyThirdIsMeasuredWhateverTheWidth() {
        XCTAssertFalse(Int32(1).isPastExactNumbers)
        XCTAssertFalse(Int32.max.isPastExactNumbers)
        XCTAssertFalse(Int32.min.isPastExactNumbers)
        XCTAssertFalse((Int64(1) << 53).isPastExactNumbers)
        XCTAssertTrue(((Int64(1) << 53) + 1).isPastExactNumbers)
        XCTAssertTrue(Int64.min.isPastExactNumbers)
    }

    func testAKeptWholeNumberNoIntHoldsComesBackAsNothing() {
        for number in unheld {
            XCTAssertNil(Int(persisted: .number(number)), "\(number) kept on disk")
        }
        XCTAssertEqual(Int(persisted: .number(42)), 42)
    }

    func testACarriedWholeNumberNoIntHoldsComesBackAsNothing() {
        for number in unheld {
            XCTAssertNil(Int(carried: .lanes([number])), "\(number) read from the host")
        }
        XCTAssertEqual(Int(carried: .lanes([41.6])), 42, "the nearest whole number")
    }

    func testAChoiceNumberedWithNoWholeNumberComesBackAsNothing() {
        for number in unheld {
            XCTAssertNil(LineCap(carried: .lanes([number])), "\(number) as a member's number")
        }
        XCTAssertEqual(LineCap(carried: .lanes([1])), .round)
    }

    func testATimeOrADayWithNoWholeLaneComesBackAsNothing() {
        XCTAssertNil(ClockTime(carried: .lanes([.nan, 0, 0])))
        XCTAssertNil(CalendarDate(carried: .lanes([2026, .infinity, 1])))
        XCTAssertEqual(CalendarDate(carried: .lanes([2026, 10, 9])), CalendarDate(year: 2026, month: 10, day: 9))
    }

    func testAPlacementWithNoWholeDepthStandsAtNought() {
        var lanes = [Double](repeating: 0, count: Placement.lanes)
        lanes[10] = .nan
        XCTAssertEqual(Placement(carried: .lanes(lanes))?.zIndex, 0)
    }

    func testAColorChannelThatIsNoNumberIsNought() {
        let color = Color(carried: .lanes([.nan, 0.5, 1, 1]))
        XCTAssertEqual(color?.light.red, 0)
        XCTAssertEqual(color?.light.blue, 255)
    }

    func testAnOpacityThatIsNoNumberLetsNothingThrough() {
        XCTAssertEqual(Color(hex: 0xFF0000).opacity(.nan).light.alpha, 0)
        XCTAssertEqual(Color(hex: 0xFF0000).opacity(0.5).light.alpha, 128)
    }

    /// One whole number has one rounding, whichever road it came by: a payload's, a value back from the host and a
    /// carried state's lane read 2.6 alike.
    func testAWholeNumberIsRoundedAlikeOnEveryRoad() {
        for number in [2.4, 2.5, 2.6, -2.6, 0.49] {
            let lane = Int(carried: .lanes([number]))
            XCTAssertEqual(Int(propValue: .number(number)), lane, "\(number) back from the host")
            XCTAssertEqual(PropValue.number(number).int, lane, "\(number) as a payload")
        }
    }

    func testAPayloadNumberNoIntHoldsIsNoWholeNumber() {
        for number in unheld {
            XCTAssertNil(PropValue.number(number).int, "\(number) as a payload")
        }
        XCTAssertEqual(PropValue.number(2).int, 2)
    }
}
