// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import StateUIConformance
import XCTest

final class WinUIPageHeadingTests: XCTestCase {
    /// Where the window's chrome names the application, the page that names the window is headed by its title, its
    /// content under the heading; the page pushed over it takes the heading.
    func testAPageIsHeadedByItsTitleWhereTheChromeNamesTheApplication() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = WinUIRenderer.running {
                NavigationStack(path.projectedValue) {
                    Text("Home words").title("Home")
                } destination: { _ in
                    Text("Sample words").title("Button menu")
                }
                .barTitle("StateUI")
            }
            host.settle { Self.headings(host) == ["Home"] }
            XCTAssertEqual(Self.headings(host), ["Home"])

            path.wrappedValue = [1]
            host.settle { Self.headings(host) == ["Button menu"] }
            XCTAssertEqual(Self.headings(host), ["Button menu"], "the page shown heads alone")

            let sample = { host.views(WinUITextView.self).first { $0.text == "Sample words" }?.placed }
            host.settle { sample() != nil }
            let page = try XCTUnwrap(host.views(WinUISingleChildView.self).first { $0.heading != nil })
            let heading = try XCTUnwrap(page.heading?.view.placed)
            let words = try XCTUnwrap(sample())
            XCTAssertGreaterThanOrEqual(words.y, heading.y + heading.height, "the content under the heading")
        }
    }

    /// Where the chrome names the page, nothing heads it.
    func testAPageTheChromeNamesIsHeadedByNothing() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                    Text("Home words").title("Home")
                } destination: { _ in
                    Text("Sample words").title("Button menu")
                }
            }
            host.settle { host.window.map { _ in true } ?? false }
            XCTAssertEqual(Self.headings(host), [])
        }
    }

    /// The titles heading pages now.
    @MainActor
    private static func headings(_ host: WinUIRenderer) -> [String] {
        host.views(WinUISingleChildView.self).compactMap { $0.heading?.view.text }
    }
}
