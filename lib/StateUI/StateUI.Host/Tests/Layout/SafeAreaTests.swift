// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where a page's content stands against the window's safe area.
final class SafeAreaTests: XCTestCase {
    private let whole = Rect(x: 0, y: 0, width: 400, height: 800)
    private let safe = Rect(x: 0, y: 60, width: 400, height: 710)

    /// Content that says nothing, or stands clear of the bars, stands in the safe area; content let under the bars
    /// reaches the window's edge on every edge it says so.
    func testContentReachesTheWindowsEdgeWhereItLetsItselfUnderTheBars() {
        XCTAssertEqual(SafeAreaArithmetic.room(safe: safe, whole: whole, edges: nil), safe)
        XCTAssertEqual(SafeAreaArithmetic.room(safe: safe, whole: whole, edges: .uniform(.container)), safe)
        XCTAssertEqual(SafeAreaArithmetic.room(safe: safe, whole: whole, edges: .uniform(.all)), safe)
        XCTAssertEqual(SafeAreaArithmetic.room(safe: safe, whole: whole, edges: .uniform(.none)), whole)
        XCTAssertEqual(SafeAreaArithmetic.room(safe: safe, whole: whole, edges: .uniform(.keyboard)), whole)
        XCTAssertEqual(
            SafeAreaArithmetic.room(
                safe: safe, whole: whole, edges: .edges(left: .container, top: .none, right: .container, bottom: .all)),
            Rect(x: 0, y: 0, width: 400, height: 770), "under the top bar alone")
    }
}
