// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// Words the user can select: a value a host may make its control by, so another value makes the text anew.
@MainActor
final class SelectableTextTests: XCTestCase {
    func testASelectableTextCrossesAsItsValue() {
        XCTAssertEqual(Text("a").isSelectable(true).node.props["isSelectable"], .bool(true))
        XCTAssertNil(Text("a").node.props["isSelectable"], "not selectable unless said")
    }

    /// Text made selectable, or selectable no longer, is made again; other values change it in place.
    func testAnotherSelectabilityMakesTheTextAnew() {
        let renders = Renders()
        renders.render(Text("a").id("t").node)
        XCTAssertFalse(renders.render(Text("b").id("t").node).replace, "other words, the same text")
        XCTAssertTrue(renders.render(Text("b").isSelectable(true).id("t").node).replace, "made selectable")
        XCTAssertFalse(renders.render(Text("c").isSelectable(true).id("t").node).replace, "still selectable")
        XCTAssertTrue(renders.render(Text("c").id("t").node).replace, "selectable no longer")
    }
}
