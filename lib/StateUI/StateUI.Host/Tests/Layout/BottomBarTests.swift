// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where a page's bottom bar stands, what it leaves the page, and a scroller's end as the bar grows.
final class BottomBarTests: XCTestCase {
    private let whole = Rect(x: 0, y: 0, width: 400, height: 800)
    private let safe = Rect(x: 0, y: 60, width: 400, height: 710)

    /// A bar stands across the safe area at its foot as tall as it lays out, its ground out to the room's foot; the
    /// page's safe area ends above it, and a host whose bars stand beside the page gives its content the room above.
    func testABarStandsAtTheSafeAreasFootAsTallAsItLaysOut() {
        let place = BottomBarPlace(height: 50, safe: safe, whole: whole)
        XCTAssertEqual(place.bar, Rect(x: 0, y: 720, width: 400, height: 50))
        XCTAssertEqual(place.ground, Rect(x: 0, y: 720, width: 400, height: 80), "down under the home indicator")
        XCTAssertEqual(place.safe, Rect(x: 0, y: 60, width: 400, height: 660))
        XCTAssertEqual(place.above, Rect(x: 0, y: 0, width: 400, height: 720))
    }

    /// A bar is never taller than the safe area, nor shorter than nothing.
    func testABarIsNeverTallerThanTheSafeArea() {
        XCTAssertEqual(BottomBarPlace(height: 1_000, safe: safe, whole: whole).bar, safe)
        XCTAssertEqual(BottomBarPlace(height: 1_000, safe: safe, whole: whole).safe.height, 0)
        XCTAssertEqual(BottomBarPlace(height: -5, safe: safe, whole: whole).safe, safe)
    }

    /// A scroller let under a bar keeps clear the bar and what stands under it, so its last row scrolls out above.
    func testAScrollerUnderABarKeepsItsLastRowClearOfIt() {
        let place = BottomBarPlace(height: 50, safe: safe, whole: whole)
        XCTAssertEqual(SafeAreaArithmetic.clearance(room: whole, safe: place.safe),
                       Clearance(top: 60, left: 0, bottom: 80, right: 0))
    }

    /// Something stands under the bar while the page's rows run under it short of their end, or while content with
    /// no scroller runs under it; nothing where the content stands clear of the foot, or its scroller stands at its
    /// end, its last row clear above the bar.
    func testSomethingStandsUnderTheBarWhileTheRowsRunShortOfTheirEnd() {
        let end = Point(x: 0, y: 500)
        XCTAssertTrue(BottomBarPlace.covers(contentRunsUnder: true, scroller: (Point(x: 0, y: 120), end)))
        XCTAssertFalse(BottomBarPlace.covers(contentRunsUnder: true, scroller: (Point(x: 0, y: 499.6), end)), "at its end")
        XCTAssertFalse(BottomBarPlace.covers(contentRunsUnder: true, scroller: (.zero, .zero)), "rows that fit")
        XCTAssertTrue(BottomBarPlace.covers(contentRunsUnder: true, scroller: nil), "content with no scroller")
        XCTAssertFalse(BottomBarPlace.covers(contentRunsUnder: false, scroller: (.zero, end)), "content clear of it")
    }

    /// The keyboard stands over a room's foot in place of the system's bar while it is the higher, never on it.
    func testTheKeyboardStandsOverTheFootInPlaceOfTheSystemsBar() {
        XCTAssertEqual(SafeAreaArithmetic.bottom(system: 34, keyboard: 0), 34)
        XCTAssertEqual(SafeAreaArithmetic.bottom(system: 34, keyboard: 300), 300)
        XCTAssertEqual(SafeAreaArithmetic.bottom(system: 34, keyboard: 20), 34)
    }

    /// A scroller standing at its end stays at its end as what it reaches grows or shrinks, within half a point; one
    /// elsewhere, or one that reached nothing, stays where it is.
    func testAScrollerAtItsEndStaysAtItsEnd() {
        let end = Point(x: 0, y: 500)
        XCTAssertEqual(ScrollArithmetic.keptAtEnd(end, reach: end, now: Point(x: 0, y: 560)), Point(x: 0, y: 560))
        XCTAssertEqual(ScrollArithmetic.keptAtEnd(end, reach: end, now: Point(x: 0, y: 440)), Point(x: 0, y: 440))
        XCTAssertEqual(ScrollArithmetic.keptAtEnd(Point(x: 0, y: 499.6), reach: end, now: Point(x: 0, y: 560)),
                       Point(x: 0, y: 560), "within half a point")
        XCTAssertNil(ScrollArithmetic.keptAtEnd(Point(x: 0, y: 300), reach: end, now: Point(x: 0, y: 560)))
        XCTAssertNil(ScrollArithmetic.keptAtEnd(.zero, reach: .zero, now: Point(x: 0, y: 60)), "it reached nothing")
        XCTAssertNil(ScrollArithmetic.keptAtEnd(end, reach: end, now: end), "nothing moved")
    }
}
