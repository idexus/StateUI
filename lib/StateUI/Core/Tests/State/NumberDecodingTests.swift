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

    func testAColourChannelThatIsNoNumberIsNought() {
        let colour = Color(carried: .lanes([.nan, 0.5, 1, 1]))
        XCTAssertEqual(colour?.light.red, 0)
        XCTAssertEqual(colour?.light.blue, 255)
    }

    func testAnOpacityThatIsNoNumberLetsNothingThrough() {
        XCTAssertEqual(Color("#FF0000").opacity(.nan).light.alpha, 0)
        XCTAssertEqual(Color("#FF0000").opacity(0.5).light.alpha, 128)
    }

    func testAPayloadNumberNoIntHoldsIsNoWholeNumber() {
        for number in unheld {
            XCTAssertNil(PropValue.number(number).int, "\(number) as a payload")
        }
        XCTAssertEqual(PropValue.number(2).int, 2)
    }
}
