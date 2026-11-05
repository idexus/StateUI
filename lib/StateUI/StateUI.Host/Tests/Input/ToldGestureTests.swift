// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

final class ToldGestureTests: XCTestCase {
    /// A gesture taken away as it goes on has its end told once, as cancelled, and nothing more to the platform's
    /// end; the next is told even with no beginning, as a trackpad's pinch may come.
    func testAGestureTakenAwayIsToldNothingMoreToItsEnd() {
        var gesture = ToldGesture()
        XCTAssertTrue(gesture.tells(.began))
        gesture.told(.began)
        XCTAssertTrue(gesture.tells(.changed))
        gesture.told(.changed)

        XCTAssertTrue(gesture.takeAway(at: .changed), "under way: its end is told")
        gesture.told(.cancelled)
        XCTAssertFalse(gesture.isUnderWay)
        XCTAssertFalse(gesture.tells(.changed))
        XCTAssertFalse(gesture.tells(.changed))
        XCTAssertFalse(gesture.tells(.ended), "the platform's end, told to no one")
        XCTAssertTrue(gesture.tells(.changed), "the next, with no beginning")
    }

    /// A gesture taken away as it begins is told nothing, not even its end; a new beginning is told.
    func testAGestureTakenAwayAsItBeginsIsToldNothing() {
        var gesture = ToldGesture()
        XCTAssertTrue(gesture.tells(.began))

        XCTAssertFalse(gesture.takeAway(at: .began), "nothing told, no end to tell")
        XCTAssertFalse(gesture.tells(.changed))
        XCTAssertFalse(gesture.tells(.changed))
        XCTAssertTrue(gesture.tells(.began), "the next beginning")
        gesture.told(.began)
        XCTAssertTrue(gesture.tells(.changed))
    }

    /// A gesture taken away at the platform's own end takes nothing further: the next is told.
    func testAGestureTakenAwayAtItsEndLeavesTheNextFree() {
        var gesture = ToldGesture()
        gesture.told(.began)

        XCTAssertTrue(gesture.takeAway(at: .ended))
        gesture.told(.cancelled)
        XCTAssertTrue(gesture.tells(.changed))
    }

    /// A gesture the host tells begun by itself - a press going down - is the next, whatever was taken away.
    func testABeginningToldOpensTheNext() {
        var gesture = ToldGesture()
        XCTAssertFalse(gesture.takeAway(at: .changed))

        gesture.told(.began)
        XCTAssertTrue(gesture.isUnderWay)
        XCTAssertTrue(gesture.tells(.changed))
    }
}
