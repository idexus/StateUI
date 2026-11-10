// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A list as assistive technology meets it: a list of items, or a list box of options where the user chooses.
@MainActor
final class WebItemsViewTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// A list the user chooses in is a list box of options from its first frame, a list of items once it lets nobody
    /// choose, and a list box again as it lets them.
    func testAListsItemsAreOptionsWhereTheUserChooses() throws {
        WebRenderer.shared?.finish()
        let chosen = State<Int?>(wrappedValue: nil)
        let choosing = State(wrappedValue: true)
        let host = WebRenderer.running {
            let list = ItemsView(0..<20) { Text("Item \($0)") }
            (choosing.wrappedValue ? list.selection(chosen.projectedValue) : list).width(300).height(200)
        }
        let first = "document.querySelector('.stateui-item')"
        host.settle { (try? WebBrowser.truth("!!\(first)?.firstChild", on: 0)) == true }
        let roles = {
            try WebBrowser.evaluate("\(first).closest('.stateui-items').getAttribute('role') + '|' + "
                + "\(first).getAttribute('role')", on: 0)
        }
        XCTAssertEqual(try roles(), "listbox|option")

        choosing.wrappedValue = false
        host.settle { (try? roles()) == "list|listitem" }

        XCTAssertEqual(try roles(), "list|listitem")

        choosing.wrappedValue = true
        host.settle { (try? roles()) == "listbox|option" }

        XCTAssertEqual(try roles(), "listbox|option", "the same items, chosen in again")
        host.finish()
    }
}
