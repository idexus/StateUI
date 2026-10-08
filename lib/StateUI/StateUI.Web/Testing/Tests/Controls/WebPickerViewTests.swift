// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A picker's background colours its field and leaves the picture the page's look draws in it.
@MainActor
final class WebPickerViewTests: XCTestCase {
    /// A colour behind a picker is its background colour alone: the shorthand would clear the chevron the page's
    /// look draws as the field's background picture - a search field's glass too.
    func testABackgroundLeavesThePickersChevron() {
        let picker = WebPickerView()
        defer { picker.detach() }

        picker.setBackground(Color(red: 255, green: 255, blue: 255, alpha: 20).propValue)

        XCTAssertEqual(WebPage.style(of: picker.node, "background-color"), "rgb(255 255 255 / 0.078)")
        XCTAssertEqual(WebPage.style(of: picker.node, "background"), "", "the picture under it kept")
    }
}
