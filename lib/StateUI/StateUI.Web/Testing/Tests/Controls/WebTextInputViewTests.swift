// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUIWeb
import XCTest

/// A field is as wide as its words or its placeholder, as a native field measures - not the browser's twenty
/// characters, which in a row of a phone's width pushes what follows it out of the row.
@MainActor
final class WebTextInputViewTests: XCTestCase {
    func testAFieldIsAsWideAsItsWordsOrItsPlaceholder() {
        let field = WebTextInputView(.field)
        defer { field.detach() }

        field.setPlaceholder("type here")
        XCTAssertEqual(WebPage.attribute(of: field.node, "size"), "9", "its placeholder's characters")

        WebPage.enter("Words longer than the placeholder", into: field.node)
        XCTAssertEqual(WebPage.attribute(of: field.node, "size"), "33", "the words typed")
        XCTAssertEqual(WebPage.attribute(of: field.node, "class"), "stateui-field", "sized by its content where it can be")
    }
}
