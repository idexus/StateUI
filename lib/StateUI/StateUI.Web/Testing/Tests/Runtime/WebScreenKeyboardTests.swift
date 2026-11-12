// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUIWeb
import XCTest

/// The keyboard over a phone's page, from what its browser leaves visible of the page's own viewport.
final class WebScreenKeyboardTests: XCTestCase {
    /// The keyboard is what the viewport reaches past the foot of its visible part - wherever the browser has
    /// scrolled the visible part to show the field.
    func testTheKeyboardIsWhatTheViewportReachesPastTheVisiblePart() {
        XCTAssertEqual(WebScreenKeyboard.height(layout: 800, top: 0, visible: 500, scale: 1), 300)
        XCTAssertEqual(WebScreenKeyboard.height(layout: 800, top: 120, visible: 380, scale: 1), 300, "scrolled to the field")
        XCTAssertEqual(WebScreenKeyboard.height(layout: 800, top: 0, visible: 499.6, scale: 1), 300, "a whole pixel")
    }

    /// A page zoomed in shows less of itself with no keyboard, and a page its browser makes shorter for the keyboard
    /// has none over it.
    func testAZoomedPageOrOneMadeShorterHasNoKeyboardOverIt() {
        XCTAssertEqual(WebScreenKeyboard.height(layout: 800, top: 200, visible: 400, scale: 2), 0, "zoomed in")
        XCTAssertEqual(WebScreenKeyboard.height(layout: 500, top: 0, visible: 500, scale: 1), 0, "made shorter")
        XCTAssertEqual(WebScreenKeyboard.height(layout: 800, top: 0, visible: 820, scale: 1), 0, "never below nothing")
    }
}
