// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUI
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

    /// A margin below nothing shifts the child as a margin does on every host - the clock's marks stand left of
    /// and above the centre by such margins; a padding is never below nothing.
    func testAMarginBelowNothingShiftsTheChild() {
        let layout = WebLayoutView(arrangement: .grid)
        let mark = WebTextView()
        defer { for view in [layout, mark] { view.detach() } }
        var values = LayoutValues()
        values.margin = Insets(left: -188, top: -94, right: 0, bottom: 0)
        layout.setItems([(mark, values)])

        XCTAssertEqual(WebPage.style(of: mark.node, "margin-inline-start"), "-188px", "left of where it would stand")
        XCTAssertEqual(WebPage.style(of: mark.node, "margin-block-start"), "-94px", "and above it")
    }

    /// A ZStack's child keeps its own opacity as the stack places its children again: a row's press light, hidden,
    /// stays hidden as the row's look changes under the pointer.
    func testAStackedChildKeepsItsOwnOpacityAsItIsPlacedAgain() {
        let layout = WebLayoutView(arrangement: .layers)
        let light = WebLayoutView(arrangement: .single)
        defer { for view in [layout, light] { view.detach() } }
        layout.setItems([(light, LayoutValues())])
        light.setOpacity(0)

        layout.setItems([(light, LayoutValues())])
        XCTAssertEqual(WebPage.style(of: light.node, "opacity"), "0", "its own opacity, placed again")
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
