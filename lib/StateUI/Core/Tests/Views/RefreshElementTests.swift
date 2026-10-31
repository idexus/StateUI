// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The pull to refresh as the core writes it: a value shown, and the pull heard.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class RefreshElementTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// A value shows the spinner as it says and writes nothing: the pull is only heard, for the application to
    /// write its own value.
    func testAValueShowsTheSpinnerAndThePullIsHeard() throws {
        var heard = 0
        let renders = Renders()
        let patch = renders.render(ScrollView { Text("") }
            .isRefreshing(true)
            .onRefreshRequested { heard += 1 }
            .node)

        XCTAssertEqual(patch.properties[.isRefreshing], .bool(true))
        renders.fire(try XCTUnwrap(patch.events?[.refreshRequested]))
        XCTAssertEqual(heard, 1)

        let list = ItemsView(["one"]) { Text($0) }.isRefreshing(true).node.built
        XCTAssertEqual(list.props[.isRefreshing], .bool(true), "a list wears it on its collection")
    }

    /// A list keeps what it wears of the pull on its collection, and an empty one on the scroller its empty view
    /// stands in.
    func testAnEmptyListKeepsItsPull() throws {
        let heard = { (items: [String]) in
            ItemsView(items) { Text($0) }.emptyView(Text("Nothing")).isRefreshEnabled(false).onRefreshRequested {}
                .node.built
        }

        let full = heard(["one"])
        XCTAssertEqual(full.type, .itemsView)
        XCTAssertEqual(full.props[.isRefreshEnabled], .bool(false))
        XCTAssertNotNil(full.events[.refreshRequested])
        let empty = heard([])
        XCTAssertEqual(empty.type, .scrollView, "the empty view stands in a scroller")
        XCTAssertEqual(empty.props[.isRefreshEnabled], .bool(false))
        XCTAssertNotNil(empty.events[.refreshRequested], "which hears the pull")
    }
}
