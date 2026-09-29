// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where a scroller stands when the tree writes its offset.
final class ScrollOffsetTests: XCTestCase {
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

    /// An offset stands within what the scroller reaches.
    func testAnOffsetWrittenBeforeTheFirstLayoutWaitsForIt() {
        var written = WrittenScrollOffset()
        XCTAssertNil(written.written(Point(x: 0, y: 40), standing: .zero, orientation: .vertical), "no layout yet")
        XCTAssertNil(written.written(Point(x: 0, y: 90), standing: .zero, orientation: .vertical))
        XCTAssertEqual(written.laidOutNow(), Point(x: 0, y: 90), "the last one written waited")
        XCTAssertNil(written.laidOutNow(), "moved to once")
        XCTAssertEqual(written.written(Point(x: 0, y: 20), standing: .zero, orientation: .vertical), Point(x: 0, y: 20))

        var still = WrittenScrollOffset()
        XCTAssertEqual(still.written(Point(x: 5, y: 5), standing: .zero, orientation: .neither), Point(x: 0, y: 0),
                       "a scroller that scrolls neither way stands at its origin at once")
    }

    /// An offset is kept between the scroller's origin and what it reaches.
    func testAnOffsetIsKeptWithinReach() {
        XCTAssertEqual(ScrollArithmetic.kept(Point(x: -5, y: 900), reach: Point(x: 100, y: 300)), Point(x: 0, y: 300))
    }
}
