// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// Whether the bars' words are white - what a theme moving would change.
@MainActor
private final class Shade {
    @State var dark = false
    @State var path: [Int] = []
}

@MainActor private let shade = Shade()

/// Two tabs under bars whose words follow the shade, written on the tabs or on the stack they stand in.
private struct ShadedTabs: View {
    let onTheStack: Bool

    var body: some View {
        let words: Color = shade.dark ? .white : .black
        let tabs = TabView([0, 1]) { Text("\($0)").title("Tab \($0)") }
        if onTheStack {
            NavigationStack(shade.$path) { tabs } destination: { Text("\($0)") }.barForegroundColor(words)
        } else {
            tabs.barForegroundColor(words)
        }
    }
}

/// A tabbed view's strip in a running host, which a browser's page runs (`test-web.sh --browser --host`).
@MainActor
final class WebTabStripTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// The strip's words follow the bars' on its path as they change - a theme moving them, a state - written on the
    /// tabs or on the stack they stand in.
    func testTheStripFollowsTheBarsWordsAsTheyChange() throws {
        for onTheStack in [false, true] {
            shade.dark = false
            let host = WebRenderer.running { ShadedTabs(onTheStack: onTheStack) }
            defer { host.leave() }
            host.step()
            let tabs = try XCTUnwrap(host.views(WebTabView.self).first)
            let words = {
                (try? WebBrowser.evaluate("e.style.getPropertyValue('--stateui-bar-foreground')", on: tabs.strip.node))
                    ?? nil
            }
            XCTAssertEqual(words(), "rgb(0 0 0 / 1)", onTheStack ? "on the stack" : "on the tabs")

            shade.dark = true
            host.settle { words() == "rgb(255 255 255 / 1)" }

            XCTAssertEqual(words(), "rgb(255 255 255 / 1)", onTheStack ? "on the stack" : "on the tabs")
        }
    }
}
