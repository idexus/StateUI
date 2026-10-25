// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A press is a tap until it travels as far as a drag: a finger farther than a mouse, each press anew.
final class WebTapReachTests: XCTestCase {
    func testAPressIsATapUntilItTravelsAsFarAsADrag() {
        var reach = WebTapReach()
        reach.down(1, at: Point(x: 100, y: 100), kind: .touch)
        reach.moved(1, to: Point(x: 100, y: 108))
        XCTAssertTrue(reach.isTap, "a finger within ten points")
        reach.moved(1, to: Point(x: 100, y: 140))
        reach.up(1)
        XCTAssertFalse(reach.isTap, "slid off: no tap, after the lift too")

        reach.down(2, at: Point(x: 100, y: 100), kind: .mouse)
        XCTAssertTrue(reach.isTap, "a new press is a tap again")
        reach.moved(2, to: Point(x: 100, y: 106))
        XCTAssertFalse(reach.isTap, "a mouse past four points")
    }

    func testAnotherPointerMovesNoPress() {
        var reach = WebTapReach()
        reach.down(1, at: Point(x: 100, y: 100), kind: .touch)
        reach.down(2, at: Point(x: 300, y: 100), kind: .touch)
        reach.moved(2, to: Point(x: 300, y: 200))
        XCTAssertTrue(reach.isTap, "the second finger's move is not the press's")
    }
}
