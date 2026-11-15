// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import XCTest

final class WebSuiteTests: XCTestCase {
    private let listed = [
        "StateUIWebTests.WebRelayTests/testOne", "StateUIWebTests.WebLookTests/testPaint",
        "StateUIWebTests.WebConformanceTests/testButton", "StateUIWebTests.WebConformanceTests/testSlider",
    ]

    /// Unfiltered, Node runs the host's own tests a page with a DOM enough for; a browser runs every conformance
    /// family and the host's classes that run a host.
    func testTheTestsSplitWhereTheyRun() {
        let (node, browser) = WebSuite.split(listed, filter: nil)
        XCTAssertEqual(node, ["StateUIWebTests.WebRelayTests/testOne"])
        XCTAssertTrue(browser.starts(with: ["StateUIWebTests.WebConformanceTests/testButton", "StateUIWebTests.WebConformanceTests/testSlider"]))
        XCTAssertTrue(browser.contains("StateUIWebTests.WebLookTests"))
    }

    /// A filter names a family, a class or a test, which runs where it belongs.
    func testAFilterRunsWhereItBelongs() {
        XCTAssertTrue(WebSuite.split(listed, filter: "Button") == ([], ["StateUIWebTests.WebConformanceTests/testButton"]))
        XCTAssertTrue(WebSuite.split(listed, filter: "WebLookTests") == ([], ["StateUIWebTests.WebLookTests"]))
        XCTAssertTrue(WebSuite.split(listed, filter: "WebRelayTests/testOne") == (["StateUIWebTests.WebRelayTests/testOne"], []))
        // Families, a list of them: each its test, or its parts.
        let parted = listed + ["StateUIWebTests.WebConformanceTests/testVisualElement1", "StateUIWebTests.WebConformanceTests/testVisualElement2",
                               "StateUIWebTests.WebConformanceTests/testButtonMenu"]
        XCTAssertTrue(WebSuite.split(parted, filter: "Button,VisualElement") == ([], [
            "StateUIWebTests.WebConformanceTests/testButton", "StateUIWebTests.WebConformanceTests/testVisualElement1",
            "StateUIWebTests.WebConformanceTests/testVisualElement2"]))
    }
}
