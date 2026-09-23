// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// A scroller says where it went once a frame and rests once a movement: at
/// the end of a hold that ran its throw out, or once it has stood still.
final class ScrollMovementTests: XCTestCase {
    @MainActor
    func testTheMovesOfAFrameAreOneMoveAndAQuietMovementRestsOnce() {
        let movement = ScrollMovement()

        movement.userMoved(from: Point(x: 0, y: 0), to: Point(x: 0, y: 10))
        movement.userMoved(from: Point(x: 0, y: 10), to: Point(x: 0, y: 25))
        XCTAssertEqual(movement.frame(now: 0), [.moved(from: Point(x: 0, y: 0), to: Point(x: 0, y: 25))])

        XCTAssertEqual(movement.frame(now: 100), [])
        XCTAssertTrue(movement.wantsFrames, "still counting the quiet")
        XCTAssertEqual(movement.frame(now: 120), [.rested])
        XCTAssertEqual(movement.frame(now: 300), [], "said once")
        XCTAssertFalse(movement.wantsFrames)
    }

    /// A finger that holds still keeps the movement going; let go, what it threw rests once it stands still.
    @MainActor
    func testAHeldScrollerRestsOnlyAfterItIsLetGo() {
        let movement = ScrollMovement()

        movement.holdBegan()
        movement.userMoved(from: Point(x: 0, y: 0), to: Point(x: 0, y: 40))
        _ = movement.frame(now: 0)
        XCTAssertEqual(movement.frame(now: 500), [], "held, it does not rest however still it stands")

        movement.holdEnded(rests: false)
        movement.userMoved(from: Point(x: 0, y: 40), to: Point(x: 0, y: 90))
        XCTAssertEqual(movement.frame(now: 520), [.moved(from: Point(x: 0, y: 40), to: Point(x: 0, y: 90))])
        XCTAssertEqual(movement.frame(now: 600), [])
        XCTAssertEqual(movement.frame(now: 640), [.rested])
    }

    /// A finger that catches a throw carries its movement on: one rest when it is over, none lost.
    @MainActor
    func testAHoldThatCatchesAThrowRestsOnce() {
        let movement = ScrollMovement()

        movement.userMoved(from: Point(x: 0, y: 0), to: Point(x: 0, y: 30))
        _ = movement.frame(now: 0)
        movement.holdBegan()
        XCTAssertEqual(movement.frame(now: 200), [], "caught, still held")

        movement.holdEnded(rests: true)
        XCTAssertEqual(movement.frame(now: 216), [.rested])
    }

    /// A hold that moved nothing says nothing when it ends.
    @MainActor
    func testAHoldThatMovedNothingSaysNothing() {
        let movement = ScrollMovement()

        movement.holdBegan()
        movement.holdEnded(rests: true)
        XCTAssertEqual(movement.frame(now: 0), [])
        XCTAssertFalse(movement.wantsFrames)
    }
}
