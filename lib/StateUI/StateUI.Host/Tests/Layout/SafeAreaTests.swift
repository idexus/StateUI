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

    /// The room content standing so on its edges has, left to right.
    private func room(_ edges: SafeAreaEdges?) -> Rect {
        SafeAreaArithmetic.room(safe: safe, whole: whole, edges: edges, direction: .leftToRight)
    }

    /// Content that says nothing, or stands clear of the bars, stands in the safe area; content let under the bars
    /// reaches the window's edge on every edge it says so.
    func testContentReachesTheWindowsEdgeWhereItLetsItselfUnderTheBars() {
        XCTAssertEqual(room(nil), safe)
        XCTAssertEqual(room(.uniform(.container)), safe)
        XCTAssertEqual(room(.uniform(.all)), safe)
        XCTAssertEqual(room(.uniform(.none)), whole)
        XCTAssertEqual(room(.uniform(.keyboard)), whole)
        XCTAssertEqual(
            SafeAreaArithmetic.room(
                safe: safe, whole: whole, edges: .edges(start: .container, top: .none, end: .container, bottom: .all),
                direction: .leftToRight),
            Rect(x: 0, y: 0, width: 400, height: 770), "under the top bar alone")
    }

    /// The start and the end of the edges a layout says are its direction's: content let under the bars at its
    /// start reaches the window's left edge left to right and its right edge right to left.
    func testContentLetUnderTheBarsAtItsStartReachesTheEdgeItsDirectionStartsFrom() {
        let notched = Rect(x: 40, y: 60, width: 320, height: 710)
        let edges = SafeAreaEdges.edges(start: .none, top: .container, end: .container, bottom: .container)
        let ltr = SafeAreaArithmetic.room(safe: notched, whole: whole, edges: edges, direction: .leftToRight)
        let rtl = SafeAreaArithmetic.room(safe: notched, whole: whole, edges: edges, direction: .rightToLeft)
        XCTAssertEqual(ltr, Rect(x: 0, y: 60, width: 360, height: 710), "out to the left edge, left to right")
        XCTAssertEqual(rtl, Rect(x: 40, y: 60, width: 360, height: 710), "out to the right edge, right to left")
    }

    /// A scroller let under the strip at its bottom keeps that strip clear at its end, so its last row scrolls out
    /// from under it; one standing clear of the bars, or let under them at its top alone, keeps nothing.
    func testAScrollerUnderTheStripAtItsEndKeepsItClear() {
        let under = SafeAreaArithmetic.room(
            safe: safe, whole: whole, edges: .edges(start: .container, top: .container, end: .container, bottom: .none),
            direction: .leftToRight)
        XCTAssertTrue(SafeAreaArithmetic.endClearance(room: under, safe: safe) == (0, 30), "the strip under it")
        XCTAssertTrue(SafeAreaArithmetic.endClearance(room: safe, safe: safe) == (0, 0), "clear of the bars")
        let top = SafeAreaArithmetic.room(
            safe: safe, whole: whole, edges: .edges(start: .container, top: .none, end: .container, bottom: .container),
            direction: .leftToRight)
        XCTAssertTrue(SafeAreaArithmetic.endClearance(room: top, safe: safe) == (0, 0), "under the top bar alone")
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
