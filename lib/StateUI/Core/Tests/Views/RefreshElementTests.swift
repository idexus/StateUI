// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The pull to refresh as the core writes it: where the list keeps it, empty or not.

import XCTest

@_spi(Host) @testable import StateUI

@MainActor
final class RefreshElementTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
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
