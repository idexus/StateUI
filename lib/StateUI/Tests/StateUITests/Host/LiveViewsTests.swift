// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// A host's views by number, held weakly.
@MainActor
final class LiveViewsTests: XCTestCase {
    private final class View {}

    /// Each view takes the next number, is found by it while it lives, and is found no more once let go or gone.
    func testAViewIsFoundByItsNumberWhileItLives() {
        let views = LiveViews<View>()
        var view: View? = View()
        let kept = View()
        let first = views.reserve()
        let second = views.reserve()
        views.hold(view!, as: first)
        views.hold(kept, as: second)
        XCTAssertEqual(second, first + 1)
        XCTAssertTrue(views.find(first) === view)

        view = nil
        XCTAssertNil(views.find(first), "held weakly: gone with the view")
        views.release(second)
        XCTAssertNil(views.find(second))
        XCTAssertEqual(views.count, 1, "the gone view's place stays until it is released")
    }
}
