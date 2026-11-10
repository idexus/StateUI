// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A cell of a list holds its entry while the entry is near the view, and keeps the room it took along the list's
/// axis once it lets the entry go, so the items after it stand where they stood.
@MainActor
final class WebItemCellTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// A list made a row while it runs: an item scrolled far away keeps the width it took, and no height of the
    /// list's.
    func testACellScrolledAwayKeepsItsWidthInAListMadeARow() throws {
        WebRenderer.shared?.finish()
        let layout = State(wrappedValue: ItemsLayout.list())
        let host = WebRenderer.running {
            ItemsView(0..<200) { Text("Item \($0)").padding(12) }.itemsLayout(layout.wrappedValue).width(300).height(60)
        }
        let first = "document.querySelector('.stateui-item')"
        host.settle { (try? WebBrowser.truth("!!\(first)?.firstChild", on: 0)) == true }
        let list = try XCTUnwrap(host.views(WebItemsView.self).first)

        layout.wrappedValue = .row()
        host.settle { (try? WebBrowser.truth("e.dataset.layout === 'row'", on: list.node)) == true }
        for _ in 0..<3 { host.step() }
        let width = try XCTUnwrap(WebBrowser.number("\(first).getBoundingClientRect().width", on: 0))

        try WebBrowser.run("e.scrollLeft = 20000", on: list.node)
        host.settle { (try? WebBrowser.truth("!\(first).firstChild", on: 0)) == true }

        XCTAssertEqual(try WebBrowser.truth("!\(first).firstChild", on: 0), true, "the first item went far away")
        XCTAssertEqual(try WebBrowser.number("\(first).getBoundingClientRect().width", on: 0) ?? 0, width,
                       accuracy: 0.5, "the first item kept its width")
        XCTAssertEqual(try WebBrowser.evaluate("\(first).style.minHeight", on: 0), "", "a row keeps no item's height")
        host.finish()
    }

    /// An item a list scrolled far away keeps its height, which goes as the list turns into a row.
    func testAListTurnedIntoARowKeepsNoItemsHeight() throws {
        WebRenderer.shared?.finish()
        let layout = State(wrappedValue: ItemsLayout.list())
        let host = WebRenderer.running {
            ItemsView(0..<200) { Text("Item \($0)").padding(12) }.itemsLayout(layout.wrappedValue).width(300).height(60)
        }
        let first = "document.querySelector('.stateui-item')"
        host.settle { (try? WebBrowser.truth("!!\(first)?.firstChild", on: 0)) == true }
        let list = try XCTUnwrap(host.views(WebItemsView.self).first)
        try WebBrowser.run("e.scrollTop = 20000", on: list.node)
        host.settle { (try? WebBrowser.truth("!\(first).firstChild", on: 0)) == true }
        XCTAssertNotEqual(try WebBrowser.evaluate("\(first).style.minHeight", on: 0), "", "the list keeps the item's height")

        layout.wrappedValue = .row()
        host.settle { (try? WebBrowser.truth("e.dataset.layout === 'row'", on: list.node)) == true }

        XCTAssertEqual(try WebBrowser.evaluate("\(first).style.minHeight", on: 0), "", "a row keeps no item's height")
        host.finish()
    }
}
