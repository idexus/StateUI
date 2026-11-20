// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A spring: the one place its numbers are held to what a spring can be, and every law that takes one.

import XCTest

@_spi(Host) @testable import StateUI

final class SpringTests: XCTestCase {
    /// THE SPRING WHERE NEITHER NUMBER IS SAID answers in 300 milliseconds and comes to rest without passing.
    func testTheSpringWhereNeitherNumberIsSaid() {
        XCTAssertEqual(Spring().milliseconds, 300)
        XCTAssertEqual(Spring().damping, 1)
    }

    /// EVERY ENTRY POINT HOLDS A SPRING'S NUMBERS ALIKE: a motion's and a layout body's of either kind take the same
    /// floors, and the same spring where neither number is said.
    func testEveryEntryPointHoldsASpringsNumbersAlike() {
        let floors = Spring(response: .zero, damping: 0)
        XCTAssertEqual(Motion.spring(response: .zero, damping: 0).kind, .spring(milliseconds: floors.milliseconds, damping: floors.damping))
        XCTAssertEqual(LayoutBody.onChange(response: .zero, damping: 0).spring, floors)
        XCTAssertEqual(LayoutBody.followsLayout(response: .zero, damping: 0).spring, floors)

        XCTAssertEqual(Motion.spring().kind, .spring(milliseconds: 300, damping: 1))
        XCTAssertEqual(LayoutBody.onChange().spring, Spring())
        XCTAssertEqual(LayoutBody.followsLayout().spring, Spring())
    }

    /// A RESPONSE IS TO THE MILLISECOND AND AT LEAST ONE; a damping is at least 0.05, and one that is no number 1.
    func testASpringsNumbersAreHeld() {
        XCTAssertEqual(Spring(response: .microseconds(260_400)).milliseconds, 260)
        XCTAssertEqual(Spring(response: .zero).milliseconds, 1)
        XCTAssertEqual(Spring(response: .seconds(-3)).milliseconds, 1)

        XCTAssertEqual(Spring(damping: 0.4).damping, 0.4)
        XCTAssertEqual(Spring(damping: 0).damping, 0.05)
        XCTAssertEqual(Spring(damping: -2).damping, 0.05)
        XCTAssertEqual(Spring(damping: .nan).damping, 1)
        XCTAssertEqual(Spring(damping: .infinity).damping, 1)
    }

    /// TWO SPRINGS OF THE SAME NUMBERS ARE ONE, however they were written.
    func testSpringsCompareByWhatTheyHold() {
        XCTAssertEqual(Spring(response: .milliseconds(300), damping: 1), Spring())
        XCTAssertEqual(Spring(damping: 0), Spring(damping: 0.05), "held alike")
        XCTAssertNotEqual(Spring(response: .milliseconds(240)), Spring())
    }

    /// A MOTION'S SPRING IS THE NUMBERS IT WAS GIVEN, held, and 300 milliseconds damped to rest where none is said.
    func testAMotionTakesASpring() {
        XCTAssertEqual(Motion.spring().kind, .spring(milliseconds: 300, damping: 1))
        XCTAssertEqual(
            Motion.spring(response: .milliseconds(260), damping: 0.7).kind,
            .spring(milliseconds: 260, damping: 0.7))
        XCTAssertEqual(Motion.spring(damping: 0).kind, .spring(milliseconds: 300, damping: 0.05))
    }

    /// A LAYOUT BODY FOLLOWS ITS PLACE ON THE SPRING IT WAS GIVEN, and crosses to the host and back as it is.
    func testALayoutBodyTakesASpring() throws {
        XCTAssertEqual(LayoutBody.followsLayout().spring, Spring())

        let body = LayoutBody.followsLayout(response: .milliseconds(420), damping: 0.6)
        XCTAssertEqual(body.spring, Spring(response: .milliseconds(420), damping: 0.6))
        XCTAssertEqual(try XCTUnwrap(LayoutBody(propValue: body.propValue)), body)
    }

    /// A SPRING BACK FROM NUMBERS IS HELD AS ONE WRITTEN: numbers that are none give the standard response and a
    /// damping of 1.
    func testASpringBackFromItsNumbersIsHeld() {
        XCTAssertEqual(Spring(milliseconds: 420, damping: 0.6), Spring(response: .milliseconds(420), damping: 0.6))
        XCTAssertEqual(Spring(milliseconds: .nan, damping: .nan), Spring())
        XCTAssertEqual(Spring(milliseconds: -5, damping: 0).milliseconds, 1)
    }
}
