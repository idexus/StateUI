// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@testable import StateUIWeb
import XCTest

/// A document written in place with an address of its own takes it as a `<base>` after its doctype: before it, the
/// browser reads the document in quirks mode.
final class WebFrameDocumentTests: XCTestCase {
    func testTheBaseStandsAfterTheDoctype() {
        XCTAssertEqual(
            WebRelay.document("<!DOCTYPE html><html><body>Hi</body></html>", base: "https://example.com/docs/"),
            #"<!DOCTYPE html><base href="https://example.com/docs/"><html><body>Hi</body></html>"#)
        XCTAssertEqual(
            WebRelay.document("\n  <!doctype html>\n<p>Hi", base: "https://example.com/"),
            "\n  <!doctype html>" + #"<base href="https://example.com/">"# + "\n<p>Hi")
        XCTAssertEqual(
            WebRelay.document("<p>Hi</p>", base: #"https://example.com/?a=1&b="2""#),
            #"<base href="https://example.com/?a=1&amp;b=&quot;2&quot;"><p>Hi</p>"#, "a document of no doctype")
        XCTAssertEqual(WebRelay.document("<p>Hi</p>", base: nil), "<p>Hi</p>", "no address of its own")
    }
}
