// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
import StateUIWebView

/// A web view's values as they cross to a host and back.
final class WebViewValueTests: XCTestCase {
    /// A source crosses as its kind, then what it is made of; a kind without its parts reads as no value.
    func testASourceCrossesAsItsKindThenItsParts() {
        XCTAssertEqual(
            WebViewSource.url("https://example.com").propValue, .values([.enumeration(0), .string("https://example.com")]))
        XCTAssertEqual(
            WebViewSource.html("<p>Hi</p>", baseUrl: nil).propValue,
            .values([.enumeration(1), .string("<p>Hi</p>"), .nothing]))
        XCTAssertNil(WebViewSource(propValue: .values([.enumeration(1), .string("<p/>")])), "two places, not three")
    }

    /// Every value reads back as it crossed.
    func testEveryValueReadsBackAsItCrossed() {
        let sources = [
            WebViewSource.url("https://example.com"), .html("<p/>", baseUrl: nil),
            .html("<p/>", baseUrl: "https://example.com"),
        ]
        for source in sources { XCTAssertEqual(WebViewSource(propValue: source.propValue), source) }
        XCTAssertEqual(WebNavigationEvent(propValue: WebNavigationEvent.back.propValue), .back)
        XCTAssertEqual(WebNavigationResult(propValue: WebNavigationResult.success.propValue), .success)
    }

    /// Each report's payload decodes as its contract declares.
    func testEveryReportsPayloadDecodesAsDeclared() {
        let address = PropValue.string("https://example.com")
        XCTAssertNotNil(MemberValues.decode([.bool(true)], as: Bool.self))
        XCTAssertNotNil(MemberValues.decode(
            [.enumeration(1), .enumeration(3), address], as: WebNavigationResult.self, WebNavigationEvent.self,
            String.self))
        XCTAssertNotNil(MemberValues.decode([.enumeration(3), address], as: WebNavigationEvent.self, String.self))
    }
}
