// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
import StateUIWebView

/// A web view as the tree describes it, and what its host reports.
final class WebViewControlTests: XCTestCase {
    /// Everything of its own a web view can be given reaches its host: the page, the agent, the two ways as watches,
    /// and its three reports.
    func testAWebViewCarriesWhatItIsGiven() {
        let (hasBack, hasForward) = (State(false), State(false))
        let patch = Renders().render(
            WebView("https://example.com/docs")
                .userAgent("StateUI/1.0")
                .canGoBack(hasBack.projectedValue)
                .canGoForward(hasForward.projectedValue)
                .onNavigating { _ in }
                .onNavigated { _ in }
                .onProcessTerminated {}
                .body)

        XCTAssertEqual(patch.properties[WebViewContract.source.token], WebViewSource.url("https://example.com/docs").propValue)
        XCTAssertEqual(patch.properties[WebViewContract.userAgent.token], .string("StateUI/1.0"))
        XCTAssertEqual(
            Set(patch.events.map { $0.handlers.keys.map(\.name) } ?? []),
            ["canGoBackChanged", "canGoForwardChanged", "navigated", "navigating", "processTerminated"])
    }

    /// A navigation that arrives with no reason still reports: the address and the outcome beside it are good. A
    /// reason neither side names reads as unknown rather than taking the report down.
    func testANavigationWithNoReasonStillReports() {
        var seen: [WebNavigated] = []
        let renders = Renders()
        let patch = renders.render(WebView("https://example.com").onNavigated { seen.append($0) }.body)
        let navigated = patch.events?.handlers[WebViewContract.navigated.token]

        renders.fire(navigated, with: [
            .enumeration(WebNavigationResult.success.rawValue), .enumeration(WebNavigationEvent.unknown.rawValue),
            .string("https://example.com/"),
        ])
        renders.fire(navigated, with: [.enumeration(9), .enumeration(9), .string("https://example.com/")])

        XCTAssertEqual(seen.map(\.result), [.success, .unknown])
        XCTAssertEqual(seen.map(\.event), [.unknown, .unknown])
        XCTAssertEqual(seen.first?.url, "https://example.com/")
    }

    /// A report of the wrong kind is a garbled payload, not an unnamed reason: nothing runs.
    func testANavigationReportOfTheWrongShapeLeavesTheHandlerAlone() {
        var seen: [WebNavigation] = []
        let renders = Renders()
        let patch = renders.render(WebView("https://example.com").onNavigating { seen.append($0) }.body)

        renders.fire(patch.events?.handlers[WebViewContract.navigating.token], with: [
            .number(Double(WebNavigationEvent.newPage.rawValue)), .string("https://example.com/"),
        ])

        XCTAssertTrue(seen.isEmpty)
    }
}

extension HostEventUpdate {
    /// The handlers this update names, by event.
    var handlers: [Event: Int32] {
        switch self {
        case .replace(let handlers): handlers
        }
    }
}
