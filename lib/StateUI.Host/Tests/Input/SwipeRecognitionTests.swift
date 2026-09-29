// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

final class SwipeRecognitionTests: XCTestCase {
    /// A press that moved goes the one way it moved most: across when it moved at least as far across as down.
    func testASwipeGoesAlongTheAxisItMovedMost() {
        XCTAssertEqual(SwipeDirection.swiped(x: 60, y: 20, listening: .all, threshold: 40), .right)
        XCTAssertEqual(SwipeDirection.swiped(x: -60, y: 59, listening: .all, threshold: 40), .left)
        XCTAssertEqual(SwipeDirection.swiped(x: 10, y: -50, listening: .all, threshold: 40), .up)
        XCTAssertEqual(SwipeDirection.swiped(x: -10, y: 50, listening: .all, threshold: 40), .down)
        XCTAssertEqual(SwipeDirection.swiped(x: 45, y: -45, listening: .all, threshold: 40), .right, "a tie is across")
    }

    /// A press that moved less than the threshold, or not at all, is no swipe.
    func testAShortPressIsNoSwipe() {
        XCTAssertNil(SwipeDirection.swiped(x: 39, y: 0, listening: .all, threshold: 40))
        XCTAssertEqual(SwipeDirection.swiped(x: 40, y: 0, listening: .all, threshold: 40), .right)
        XCTAssertNil(SwipeDirection.swiped(x: 0, y: 0, listening: .all, threshold: 0))
        XCTAssertEqual(SwipeDirection.swiped(x: 1, y: 0, listening: .all, threshold: -5), .right, "no threshold is 0")
    }

    /// A swipe a view does not listen for is none, even when it went far: its dominant way decides, not another.
    func testAWayTheViewDoesNotListenForIsNoSwipe() {
        XCTAssertNil(SwipeDirection.swiped(x: 80, y: 60, listening: [.up, .down], threshold: 40))
        XCTAssertEqual(SwipeDirection.swiped(x: -80, y: 0, listening: [.left], threshold: 40), .left)
    }
}
