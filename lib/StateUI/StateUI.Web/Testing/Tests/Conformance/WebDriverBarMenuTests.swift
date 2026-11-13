// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIConformance
@testable import StateUIWeb
import XCTest

/// The driver reads and chooses a bar's button's menu where the button stands: behind the More of its own page's bar
/// at the foot, while both pages of a split view show theirs. A host runs in the page, so the suite runs it in a
/// browser (`test-web.sh --browser`).
@MainActor
final class WebDriverBarMenuTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testAButtonBehindItsPagesFootIsReadThere() throws {
        let heard = Received<String>()
        let driver = WebDriver()
        let tree = driver.start(clock: nil, reducesMotion: true) {
            SplitView {
                Text("Places").toolbar(.bottom) {
                    ToolbarButton("Sort").onClicked {}.placement(at: .overflow).id("sort")
                        .menu { MenuItem("By name").onClicked { heard.values.append("name") }.id("byName") }
                }
            } detail: {
                Text("Notes").toolbar(.bottom) {
                    ToolbarButton("Share").onClicked {}.placement(at: .overflow).id("share")
                        .menu { MenuItem("Mail").onClicked { heard.values.append("mail") }.id("mail") }
                }
            }
            .showsSidebar(State(wrappedValue: true).projectedValue)
        }
        defer { driver.renderer?.finish() }
        for _ in 0..<5 { driver.step() }
        let element = { (id: String) in try XCTUnwrap(tree.root?.first(id: .manual(id)), id) }
        let shown = "!e.hidden && !e.closest('[hidden]')"
        let mores = driver.footToolbars(in: tree.root).map(\.more.node)
        XCTAssertEqual(try mores.filter { try WebBrowser.truth(shown, on: $0) }.count, 2, "both pages show their More")

        XCTAssertEqual(try driver.buttonMenu(of: element("share")), "Share;-;Mail", "the detail's own")
        XCTAssertEqual(try driver.buttonMenu(of: element("sort")), "Sort;-;By name", "the sidebar's own")
        try driver.perform(.activate, on: element("mail"))
        for _ in 0..<5 {
            guard heard.values.isEmpty else { break }
            driver.step()
        }
        XCTAssertEqual(heard.values, ["mail"], "chosen in the detail's")
    }
}
