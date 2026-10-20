// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// The fingers on a layout a hand moves, as a toolkit tells each, read as one hand the same on every host.
final class HandRecognitionTests: XCTestCase {
    /// The first finger down begins the hand where it went down in the view; nothing more is said until the middle
    /// passes the platform's distance, which asks the layout; a hand taken says each move after, and the last finger
    /// up ends it.
    func testAHandAsksAtTheDistanceAndSaysEveryMoveOnceTaken() {
        var hand = HandRecognition(distance: .eachAxis(x: 4, y: 4))

        XCTAssertEqual(hand.down(1, at: Point(100, 100), inView: Point(10, 20)), .began(at: Point(10, 20)))
        XCTAssertEqual(hand.moved(1, to: Point(103, 100)), .nothing, "within the distance")
        XCTAssertEqual(hand.moved(1, to: Point(106, 101)), .asks(Point(6, 1)), "past it: how far it went")
        hand.answered(taken: true)
        XCTAssertTrue(hand.isTaken)
        XCTAssertEqual(hand.moved(1, to: Point(110, 101)), .moved(Point(4, 0)))
        XCTAssertEqual(hand.moved(1, to: Point(110, 101)), .nothing, "a move of nothing says nothing")
        XCTAssertEqual(hand.up(1, letGo: true), .ended(letGo: true))
        XCTAssertFalse(hand.isTaken)
    }

    /// A second finger joins the hand, moving its middle nowhere; each finger's step moves it by that step over how
    /// many are down, and a finger lifting leaves the hand to the others.
    func testFingersMoveTheHandAtTheirMiddle() {
        var hand = HandRecognition(distance: .radius(4))
        _ = hand.down(1, at: Point(0, 0), inView: Point(0, 0))
        _ = hand.moved(1, to: Point(10, 0))
        hand.answered(taken: true)

        XCTAssertEqual(hand.down(2, at: Point(50, 50), inView: Point(50, 50)), .nothing, "joined")
        XCTAssertEqual(hand.moved(2, to: Point(54, 50)), .moved(Point(2, 0)), "a step over two fingers")
        XCTAssertEqual(hand.up(1, letGo: true), .nothing, "the other still down")
        XCTAssertEqual(hand.moved(2, to: Point(58, 50)), .moved(Point(4, 0)))
        XCTAssertEqual(hand.up(2, letGo: false), .ended(letGo: false), "taken away")
    }

    /// A hand the layout leaves says no move after - whatever holds the layout has it - and still its end, so a
    /// press waiting to hold a view lets it go; the platform's measure decides the distance.
    func testAHandLeftSaysItsEndAlone() {
        var hand = HandRecognition(distance: .radius(4))
        _ = hand.down(1, at: Point(0, 0), inView: Point(0, 0))
        XCTAssertEqual(hand.moved(1, to: Point(2.8, 2.8)), .nothing, "within the radius")
        XCTAssertEqual(hand.moved(1, to: Point(3, 3)), .asks(Point(3, 3)), "past it along the diagonal")
        hand.answered(taken: false)
        XCTAssertEqual(hand.moved(1, to: Point(30, 3)), .nothing)
        XCTAssertEqual(hand.up(1, letGo: true), .ended(letGo: true))
        XCTAssertEqual(hand.up(1, letGo: true), .nothing, "nothing down")

        var boxed = HandRecognition(distance: .eachAxis(x: 4, y: 4))
        _ = boxed.down(1, at: Point(0, 0), inView: Point(0, 0))
        XCTAssertEqual(boxed.moved(1, to: Point(3.5, 3.5)), .nothing, "within the box along both axes, past the radius")
    }
}
