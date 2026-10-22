// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where a page's content stands against the window's safe area.
@MainActor
final class SafeAreaTests: XCTestCase {
    private let whole = Rect(x: 0, y: 0, width: 400, height: 800)
    private let safe = Rect(x: 0, y: 60, width: 400, height: 710)

    /// The room content ignoring the safe area on `edges` has, left to right.
    private func room(_ edges: SafeAreaEdges) -> Rect {
        SafeAreaArithmetic.room(safe: safe, whole: whole, edges: edges, direction: .leftToRight)
    }

    /// Content ignoring the safe area on no edge stands in it; content ignoring it reaches the window's edge on every
    /// edge it says so.
    func testContentReachesTheWindowsEdgeOnEachEdgeItIgnoresTheSafeAreaOn() {
        XCTAssertEqual(room(.none), safe)
        XCTAssertEqual(room(.all), whole)
        XCTAssertEqual(room(.top), Rect(x: 0, y: 0, width: 400, height: 770), "under the top bar alone")
        XCTAssertEqual(room(.vertical), Rect(x: 0, y: 0, width: 400, height: 800), "under both")
    }

    /// The start and the end of the edges a layout says are its direction's: content let under the bars at its
    /// start reaches the window's left edge left to right and its right edge right to left.
    func testContentLetUnderTheBarsAtItsStartReachesTheEdgeItsDirectionStartsFrom() {
        let notched = Rect(x: 40, y: 60, width: 320, height: 710)
        let ltr = SafeAreaArithmetic.room(safe: notched, whole: whole, edges: .start, direction: .leftToRight)
        let rtl = SafeAreaArithmetic.room(safe: notched, whole: whole, edges: .start, direction: .rightToLeft)
        XCTAssertEqual(ltr, Rect(x: 0, y: 60, width: 360, height: 710), "out to the left edge, left to right")
        XCTAssertEqual(rtl, Rect(x: 40, y: 60, width: 360, height: 710), "out to the right edge, right to left")
    }

    /// A scroller let under the bars keeps clear what they take on each edge it reaches under - the top bar's depth
    /// at its start, the strip's at its end - so its first and last rows scroll out from under them; one standing
    /// clear of the bars keeps nothing.
    func testAScrollerUnderTheBarsKeepsItsFirstAndLastRowsClear() {
        let under = room(.all)
        XCTAssertEqual(SafeAreaArithmetic.clearance(room: under, safe: safe), Clearance(top: 60, left: 0, bottom: 30, right: 0))
        XCTAssertEqual(SafeAreaArithmetic.clearance(room: safe, safe: safe), .none, "clear of the bars")
        XCTAssertEqual(SafeAreaArithmetic.clearance(room: room(.top), safe: safe), Clearance(top: 60, left: 0, bottom: 0, right: 0))
    }

    /// A bar standing beside its page takes what stands over its own edge - reaching under it, its content clear of
    /// it and of the sides - and leaves the page the rest.
    func testABarBesideItsPageTakesItsEdgeAndLeavesThePageTheRest() {
        let over = Clearance(top: 24, left: 8, bottom: 48, right: 0)
        XCTAssertEqual(over.underABarAtTheTop.bar, Clearance(top: 24, left: 8, bottom: 0, right: 0))
        XCTAssertEqual(over.underABarAtTheTop.page, Clearance(top: 0, left: 8, bottom: 48, right: 0))
        XCTAssertEqual(over.overABarAtTheBottom.bar, Clearance(top: 0, left: 8, bottom: 48, right: 0))
        XCTAssertEqual(over.overABarAtTheBottom.page, Clearance(top: 24, left: 8, bottom: 0, right: 0))
    }

    /// A scroller keeping its start clear says where it stands from its first row clear of the bars: its toolkit's
    /// offset with the start's clearance added, and the toolkit's offset for one the tree writes less it.
    func testAScrollersOffsetCountsFromItsFirstRowClearOfTheBars() {
        let clear = Clearance(top: 60, left: 20, bottom: 30, right: 0)
        XCTAssertEqual(SafeAreaArithmetic.offset(native: Point(x: -20, y: -60), clearance: clear), Point(x: 0, y: 0))
        XCTAssertEqual(SafeAreaArithmetic.native(offset: Point(x: 0, y: 100), clearance: clear), Point(x: -20, y: 40))
        XCTAssertEqual(SafeAreaArithmetic.offset(native: Point(x: 5, y: 7), clearance: .none), Point(x: 5, y: 7))
    }

    /// A page's scroller is its content when that scrolls, or the scroller its content holds alone; content holding
    /// more than one view has none.
    @MainActor
    func testAPagesScrollerIsTheOneItsContentHoldsAlone() {
        let runtime = HostRuntime.still()
        runtime.tree.apply(Self.layout(["rows"]), complete: true)
        XCTAssertEqual(runtime.tree.root?.pageScroller?.id, .manual("rows"), "the scroller its layout holds alone")

        runtime.tree.apply(Self.layout(["rows", "foot"]), complete: true)
        XCTAssertNil(runtime.tree.root?.pageScroller, "a layout holding two views holds no page's scroller")
    }

    /// A stack holding a scroller for each name, the first of them, and text for the rest.
    private static func layout(_ names: [String]) -> HostPatch {
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged(names.enumerated().map { index, name in
            HostPatch(id: .manual(name), type: index == 0 ? .scrollView : .text)
        })
        return stack
    }
}
