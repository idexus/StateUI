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
    /// Where the window's chrome names the application - over a split view's sidebar - the page that names the window
    /// is headed by its title and the line under it, its content under the heading; the page pushed over it takes the
    /// heading.
    func testAPageIsHeadedByItsTitleWhereTheChromeNamesTheApplication() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = WinUIRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    Text("Menu").title("StateUI")
                } detail: {
                    NavigationStack(path.projectedValue) {
                        Text("Home words").title("Home")
                    } destination: { _ in
                        Text("Sample words").title("Button menu").subtitle("Menus")
                    }
                }
            }
            host.settle { Self.headings(host) == ["Home"] }
            XCTAssertEqual(Self.headings(host), ["Home"])

            path.wrappedValue = [1]
            host.settle { Self.headings(host) == ["Button menu"] }
            XCTAssertEqual(Self.headings(host), ["Button menu"], "the page shown heads alone")
            let headed = try XCTUnwrap(host.views(WinUILayoutView.self).first { $0.heading != nil }?.heading)
            XCTAssertEqual(headed.line.text, "Menus", "the line under its title")

            let sample = { host.views(WinUITextView.self).first { $0.text == "Sample words" }?.placed }
            host.settle { sample() != nil }
            let page = try XCTUnwrap(host.views(WinUILayoutView.self).first { $0.heading != nil })
            let heading = try XCTUnwrap(page.heading?.view.placed)
            let words = try XCTUnwrap(sample())
            XCTAssertGreaterThanOrEqual(words.y, heading.y + heading.height, "the content under the heading")
        }
    }

    /// A tab view naming the window is headed by its title, its row of tabs under the heading - not across the
    /// window over it - and the tab's page under the row.
    func testATabViewNamingTheWindowIsHeadedOverItsTabs() throws {
        try onUIThread {
            let path = State(wrappedValue: [Int]())
            let host = WinUIRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    Text("Menu").title("StateUI")
                } detail: {
                    NavigationStack(path.projectedValue) {
                        Text("Home words").title("Home")
                    } destination: { _ in
                        TabView([1, 2]) { number in Text("Example words").title("Example \(number)") }.title("Items")
                    }
                }
            }
            path.wrappedValue = [1]
            host.settle { Self.headings(host) == ["Items"] }
            XCTAssertEqual(Self.headings(host), ["Items"])

            let tabs = try XCTUnwrap(host.views(WinUITabView.self).first)
            let heading = { tabs.heading?.view.placed }
            let row = { tabs.row.placed }
            let page = { tabs.heldViews().last?.placed }
            host.settle { heading() != nil && row() != nil && page() != nil }
            let placed = try XCTUnwrap(heading())
            let tabsRow = try XCTUnwrap(row())
            XCTAssertGreaterThanOrEqual(tabsRow.y, placed.y + placed.height, "the tabs under the heading")
            XCTAssertGreaterThanOrEqual(try XCTUnwrap(page()).y, tabsRow.y + tabsRow.height, "the tab's page under them")
            XCTAssertFalse(try XCTUnwrap(host.window).tabsStandInWindow, "no tabs across the window over the heading")
        }
    }

    /// A page saying it shows no title is headed by nothing, though the chrome names the application.
    func testAPageShowingNoTitleIsHeadedByNothing() {
        onUIThread {
            let host = WinUIRenderer.running {
                SplitView(State(wrappedValue: true).projectedValue) {
                    Text("Menu").title("StateUI")
                } detail: {
                    NavigationStack(State(wrappedValue: [Int]()).projectedValue) {
                        Text("Home words").title("Home").showsTitle(false)
                    } destination: { _ in
                        Text("Sample words").title("Button menu")
                    }
                }
            }
            host.settle { host.views(WinUITextView.self).contains { $0.text == "Home words" } }
            XCTAssertEqual(Self.headings(host), [])
        }
    }

    /// Where the chrome names the page, nothing heads it.
    func testAPageTheChromeNamesIsHeadedByNothing() {
        onUIThread {
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
        host.views(WinUILayoutView.self).compactMap { $0.heading?.view.text }
    }
}
