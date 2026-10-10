// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// The tab names the page the user sees beside the site's name the page's head gives - its `application-name` - and
/// names it as the page alone where the head gives none. The head and the tab are the browser's page, so the suite
/// runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebTabTitleTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testTheTabNamesThePageBesideTheSite() throws {
        try nameSite("StateUI")
        defer { forgetSite() }

        XCTAssertEqual(try tab { Text("Welcome").title("Home") }, "Home - StateUI")
    }

    func testAPageWithoutATitleOrTheSitesOwnNamesTheTabAsTheSite() throws {
        try nameSite("StateUI")
        defer { forgetSite() }

        XCTAssertEqual(try tab { Text("Welcome") }, "StateUI")
        XCTAssertEqual(try tab { Text("Welcome").title("StateUI") }, "StateUI")
    }

    func testWithoutASiteNameTheTabIsThePagesTitle() throws {
        XCTAssertEqual(try tab { Text("Welcome").title("Home") }, "Home")
    }

    // MARK: - Support

    /// Gives the page's head the site's name, as an application's `Page/head.html` does.
    private func nameSite(_ name: String) throws {
        try WebBrowser.run("""
            const meta = document.createElement('meta');
            meta.name = 'application-name';
            meta.content = '\(name)';
            document.head.append(meta);
            """)
    }

    /// Takes the site's name off the page's head again, for the tests after.
    private func forgetSite() {
        try? WebBrowser.run("document.querySelector('meta[name=\"application-name\"]')?.remove()")
    }

    /// What the tab says once a host shows `page`.
    private func tab(@ViewBuilder _ page: @escaping @MainActor () -> any View) throws -> String? {
        let host = WebRenderer.running(page)
        defer { host.leave() }
        for _ in 0..<3 { host.step() }
        return try WebBrowser.evaluate("document.title", on: 0)
    }
}
