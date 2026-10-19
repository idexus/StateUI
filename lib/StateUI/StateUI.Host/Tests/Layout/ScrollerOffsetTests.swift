// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where a scroller stands: the offset the tree writes, and what its toolkit says it moved to.
@MainActor
final class ScrollerOffsetTests: XCTestCase {
    /// A scroller that scrolls neither way stands at its origin; an offset it stands at already, none, or one that
    /// is no number moves nothing; any other moves it.
    func testAnOffsetTheTreeWritesMovesTheScrollerOnlyWhereItAsksSomething() {
        let standing = Point(x: 0, y: 40)
        XCTAssertEqual(ScrollArithmetic.offsetWritten(Point(x: 0, y: 90), standing: standing, orientation: .neither),
                       Point(x: 0, y: 0))
        XCTAssertNil(ScrollArithmetic.offsetWritten(Point(x: 0, y: 40.3), standing: standing, orientation: .vertical))
        XCTAssertNil(ScrollArithmetic.offsetWritten(nil, standing: standing, orientation: .vertical))
        XCTAssertNil(ScrollArithmetic.offsetWritten(Point(x: 0, y: .nan), standing: standing, orientation: .vertical))
        XCTAssertEqual(ScrollArithmetic.offsetWritten(Point(x: 0, y: 90), standing: standing, orientation: .vertical),
                       Point(x: 0, y: 90))
    }

    /// An offset written before the first layout waits for it, the last one written - but not where nothing scrolls.
    func testAnOffsetWrittenBeforeTheFirstLayoutWaitsForIt() {
        var offset = ScrollerOffset()
        XCTAssertNil(offset.written(Point(x: 0, y: 40), orientation: .vertical), "no layout yet")
        XCTAssertNil(offset.written(Point(x: 0, y: 90), orientation: .vertical))
        XCTAssertEqual(offset.laidOutNow(), Point(x: 0, y: 90), "the last one written waited")
        XCTAssertNil(offset.laidOutNow(), "moved to once")
        XCTAssertEqual(offset.written(Point(x: 0, y: 20), orientation: .vertical), Point(x: 0, y: 20))

        var still = ScrollerOffset()
        XCTAssertEqual(still.written(Point(x: 5, y: 5), orientation: .neither), Point(x: 0, y: 0),
                       "a scroller that scrolls neither way stands at its origin at once")
    }

    /// An offset is kept between the scroller's origin and what it reaches.
    func testAnOffsetIsKeptWithinReach() {
        XCTAssertEqual(ScrollArithmetic.kept(Point(x: -5, y: 900), reach: Point(x: 100, y: 300)), Point(x: 0, y: 300))
    }

    /// Before its first layout the last offset written waits - one written back to where the scroller stands
    /// included, which then leaves nothing waiting.
    func testAnOffsetWrittenBackBeforeLayoutLeavesNothingWaiting() {
        var offset = ScrollerOffset()

        XCTAssertNil(offset.written(Point(x: 0, y: 500), orientation: .vertical))
        XCTAssertNil(offset.written(Point(x: 0, y: 0), orientation: .vertical))

        XCTAssertNil(offset.laidOutNow(), "the state says 0, so the scroller stays")
    }

    /// What the toolkit says inside the program's write is the program's move, wherever it stopped the scroller.
    func testWhatTheToolkitSaysInsideTheProgramsWriteIsTheProgramsMove() {
        var offset = ScrollerOffset()
        XCTAssertTrue(offset.programMoves(to: Point(x: 0, y: 300)))

        var heard: (from: Point, to: Point)?
        ProgramWrite.perform { heard = offset.toolkitMoved(to: Point(x: 0, y: 280)) }

        XCTAssertNil(heard, "the program's move")
        XCTAssertEqual(offset.standing, Point(x: 0, y: 280), "where the toolkit stood it")
        XCTAssertEqual(offset.toolkitMoved(to: Point(x: 0, y: 300.2))?.to, Point(x: 0, y: 300.2),
                       "nothing waits once it was said: a word near the target after it is the user's")
    }

    /// A toolkit that says the program's move later is heard arriving within half a point of where the program
    /// moved it; a word further off is the user's, from where the program put it.
    func testAMoveSaidLaterArrivesWithinHalfAPoint() {
        var near = ScrollerOffset()
        XCTAssertTrue(near.programMoves(to: Point(x: 0, y: 100)))
        XCTAssertNil(near.toolkitMoved(to: Point(x: 0, y: 100.3)), "landed a fraction off: the program's move")
        XCTAssertEqual(near.standing, Point(x: 0, y: 100.3))

        var far = ScrollerOffset()
        XCTAssertTrue(far.programMoves(to: Point(x: 0, y: 100)))
        let heard = far.toolkitMoved(to: Point(x: 0, y: 100.7))
        XCTAssertEqual(heard?.from, Point(x: 0, y: 100))
        XCTAssertEqual(heard?.to, Point(x: 0, y: 100.7))
    }

    /// The program's move to where the scroller stands within half a point moves nothing, and nothing waits.
    func testAMoveToWhereTheScrollerStandsMovesNothing() {
        var offset = ScrollerOffset()
        XCTAssertFalse(offset.programMoves(to: Point(x: 0, y: 0.4)))
        XCTAssertEqual(offset.standing, Point(x: 0, y: 0))
        XCTAssertEqual(offset.toolkitMoved(to: Point(x: 0, y: 0.3))?.to, Point(x: 0, y: 0.3), "the user's")
    }

    /// A toolkit that keeps the move within what it reaches itself says where it stopped: its word to come says
    /// that, and is the program's; one that did not move says nothing, and nothing waits.
    func testAToolkitStoppingTheMoveSaysWhere() {
        var stopped = ScrollerOffset()
        XCTAssertTrue(stopped.programMoves(to: Point(x: 0, y: 900)))
        stopped.programLanded(at: Point(x: 0, y: 640))
        XCTAssertEqual(stopped.standing, Point(x: 0, y: 640))
        XCTAssertNil(stopped.toolkitMoved(to: Point(x: 0, y: 640)), "the end the toolkit stopped it at")

        var still = ScrollerOffset()
        XCTAssertTrue(still.programMoves(to: Point(x: 0, y: 900)))
        still.programLanded(at: Point(x: 0, y: 0))
        XCTAssertEqual(still.toolkitMoved(to: Point(x: 0, y: 0.2))?.to, Point(x: 0, y: 0.2),
                       "a move that went nowhere leaves nothing waiting")
    }

    /// The user taking hold makes a move of the program's still on its way theirs.
    func testTheUsersHoldMakesAMoveOnItsWayTheirs() {
        var offset = ScrollerOffset()
        XCTAssertTrue(offset.programMoves(to: Point(x: 0, y: 100)))
        offset.userTookHold()

        let heard = offset.toolkitMoved(to: Point(x: 0, y: 100))
        XCTAssertNil(heard, "standing where the program put it is no move")
        XCTAssertEqual(offset.toolkitMoved(to: Point(x: 0, y: 100.2))?.from, Point(x: 0, y: 100))
    }
}
