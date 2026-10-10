// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// A tabbed view shows the tab chosen, the others kept beside it covered, and tells the user's choice.
@MainActor
final class WebTabViewTests: XCTestCase {
    func testTheTabTheUserChoosesShowsAndIsTold() {
        let tabs = WebTabView()
        let (first, second) = (WebDOMView(tag: "section"), WebDOMView(tag: "section"))
        defer { for view in [tabs, first, second] { view.detach() } }
        var told: [(Int, Int)] = []
        tabs.onSelection = { told.append(($0, $1)) }

        tabs.setTabs([first, second])
        tabs.show(["Example", "In Code"], icons: [], requested: 0)
        XCTAssertNil(WebPage.attribute(of: first.node, "data-covered"))
        XCTAssertEqual(WebPage.attribute(of: second.node, "data-covered"), "")

        let strip = WebPage.children(of: tabs.node)[0]
        let names = WebPage.children(of: strip)
        // Each tab holds its picture, then its words.
        XCTAssertEqual(names.map { WebPage.text(of: WebPage.children(of: $0)[1]) }, ["Example", "In Code"])
        WebPage.tap(names[1])

        XCTAssertEqual(told.map(\.0), [0])
        XCTAssertEqual(told.map(\.1), [1])
        XCTAssertEqual(WebPage.attribute(of: first.node, "data-covered"), "")
        XCTAssertNil(WebPage.attribute(of: second.node, "data-covered"))
        XCTAssertEqual(WebPage.attribute(of: names[1], "aria-selected"), "true")
    }

    /// Every page stands in the one cell the pages share: a covered page is laid out unseen, so a page in a cell of
    /// its own would push the chosen one down and halve its room.
    func testEveryPageStandsInTheOneCell() {
        let tabs = WebTabView()
        let pages = [WebDOMView(tag: "section"), WebDOMView(tag: "section"), WebDOMView(tag: "section")]
        defer { for view in [tabs] + pages { view.detach() } }

        tabs.setTabs(pages)

        for page in pages {
            XCTAssertEqual(WebPage.style(of: page.node, "grid-area"), "1 / 1 / 2 / 2", "each page over the whole cell")
        }
    }

    /// The strip wears the colour of the bars on its path, with no blur under a clear one, and the bar's own look
    /// where nothing is said.
    func testTheStripWearsTheBarsColour() {
        let tabs = WebTabView()
        defer { tabs.detach() }

        tabs.showColors(background: Color.transparent.propValue, foreground: nil)
        XCTAssertEqual(WebPage.style(of: tabs.strip.node, "--stateui-bar-background"), "rgb(255 255 255 / 0)")
        XCTAssertEqual(WebPage.style(of: tabs.strip.node, "--stateui-bar-filter"), "none", "a clear bar blurs nothing")

        tabs.showColors(background: nil, foreground: nil)
        XCTAssertEqual(WebPage.style(of: tabs.strip.node, "--stateui-bar-background"), "", "the bar's own look")
        XCTAssertEqual(WebPage.style(of: tabs.strip.node, "--stateui-bar-filter"), "")
    }
}
