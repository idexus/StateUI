// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
import StateUIWebView
@_spi(Host) import StateUIWebViewConformance

/// The web view's conformance family: it covers the element and each member of its own, each case once by name.
final class WebViewFamilyTests: XCTestCase {
    func testTheFamilyCoversTheElementAndEachOfItsMembers() {
        let covered = Set(WebViewTests.cases.flatMap(\.proves).filter { $0.element == "WebView" && $0.tier == nil }
            .map { $0.member ?? "" })
        let missing = ([""] + WebViewContract.members.map(\.name)).filter { !covered.contains($0) }

        XCTAssertEqual(missing, [], "WebViewTests has no case of these")
    }

    func testEveryCaseCoversSomethingUnderANameOfItsOwn() {
        let names = WebViewTests.cases.map(\.name)
        XCTAssertEqual(Set(names).count, names.count)
        XCTAssertEqual(WebViewTests.cases.filter { $0.proves.isEmpty }.map(\.name), [])
    }
}
