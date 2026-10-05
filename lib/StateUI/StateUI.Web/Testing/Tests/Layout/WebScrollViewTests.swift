// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// A scroller keeps the user's scrolling to itself only along the ways it scrolls: across it, the scrolling goes
/// on to the scroller around it.
@MainActor
final class WebScrollViewTests: XCTestCase {
    func testAScrollerKeepsOnlyTheWaysItScrolls() {
        let scroller = WebScrollView()
        defer { scroller.detach() }

        scroller.apply(orientation: .horizontal, bars: .automatic, offset: nil)
        XCTAssertEqual(WebPage.style(of: scroller.node, "overscroll-behavior-x"), "contain")
        XCTAssertEqual(WebPage.style(of: scroller.node, "overscroll-behavior-y"), "auto", "down, the page scrolls on")

        scroller.apply(orientation: .vertical, bars: .automatic, offset: nil)
        XCTAssertEqual(WebPage.style(of: scroller.node, "overscroll-behavior-x"), "auto")
        XCTAssertEqual(WebPage.style(of: scroller.node, "overscroll-behavior-y"), "contain")
    }
}
