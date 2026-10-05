// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A layout stands its children's elements on the page in the tree's order.
@MainActor
final class WebLayoutViewTests: XCTestCase {
    /// Reordered, the children stand in their new order: each takes its place in turn, whatever stood there before.
    func testAReorderedLayoutStandsItsChildrenInTheirNewOrder() {
        let layout = WebLayoutView(arrangement: .stack(.vertical))
        let (a, b, c) = (WebTextView(), WebTextView(), WebTextView())
        defer { for view in [layout, a, b, c] { view.detach() } }

        layout.setItems([a, b, c].map { ($0, LayoutValues()) })
        XCTAssertEqual(WebPage.children(of: layout.node), [a.node, b.node, c.node])

        layout.setItems([c, b, a].map { ($0, LayoutValues()) })
        XCTAssertEqual(WebPage.children(of: layout.node), [c.node, b.node, a.node])

        layout.setItems([b, a].map { ($0, LayoutValues()) })
        XCTAssertEqual(WebPage.children(of: layout.node), [b.node, a.node], "a child no longer held leaves")
    }
}

/// A child let go of before its layout arranges again - a page popped off a stack - is left alone.
@MainActor
final class WebLayoutViewLeavingTests: XCTestCase {
    func testAChildLetGoOfFirstLeavesItsLayoutAlone() {
        let layout = WebLayoutView(arrangement: .single)
        let (kept, gone) = (WebTextView(), WebTextView())
        defer { for view in [layout, kept] { view.detach() } }

        layout.setItems([kept, gone].map { ($0, LayoutValues()) })
        gone.detach()
        layout.setItems([(kept, LayoutValues())])

        XCTAssertEqual(WebPage.children(of: layout.node), [kept.node])
    }
}
