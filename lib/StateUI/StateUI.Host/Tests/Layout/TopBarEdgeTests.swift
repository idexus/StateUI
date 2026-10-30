// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// When a page's top bar shows its edge, the same on every host drawing it.
final class TopBarEdgeTests: XCTestCase {
    /// Something stands under the bar once the rows let under it scroll past their start, and always where content
    /// with no scroller runs under it; nothing where the content stands clear of the top, or its scroller stands at
    /// its start, its first row clear below the bar.
    func testSomethingStandsUnderTheBarOnceTheRowsScrollPastTheirStart() {
        XCTAssertTrue(TopBarEdge.covers(contentRunsUnder: true, scrollerOffset: Point(x: 0, y: 120)))
        XCTAssertFalse(TopBarEdge.covers(contentRunsUnder: true, scrollerOffset: Point(x: 0, y: 0.4)), "at its start")
        XCTAssertTrue(TopBarEdge.covers(contentRunsUnder: true, scrollerOffset: nil), "content with no scroller")
        XCTAssertFalse(TopBarEdge.covers(contentRunsUnder: false, scrollerOffset: Point(x: 0, y: 120)), "content clear of it")
    }
}
