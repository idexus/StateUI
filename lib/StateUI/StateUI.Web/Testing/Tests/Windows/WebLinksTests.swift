// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// A link into the application on the Web is the page's address with a fragment: told as the page starts and as
/// the fragment changes. The address is the browser's, so the suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebLinksTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testALinkIsThePagesAddressWithAFragment() throws {
        try WebBrowser.run("history.replaceState(null, '', location.pathname + location.search)")
        let heard = Heard()
        let host = WebRenderer.running(application: { LinkedApplication(heard: heard) })
        defer {
            host.leave()
            try? WebBrowser.run("history.replaceState(null, '', location.pathname + location.search)")
        }
        for _ in 0..<5 { host.step() }
        XCTAssertEqual(heard.addresses, [], "the page's own address is no link")

        try WebBrowser.run("location.hash = 'note/7'")
        for _ in 0..<20 {
            guard heard.addresses.isEmpty else { break }
            host.step()
        }
        XCTAssertEqual(heard.addresses.count, 1, "the fragment changed")
        XCTAssertTrue(heard.addresses.last?.hasSuffix("#note/7") == true, "the whole address: \(heard.addresses)")
    }

    /// A fragment's move is a link, not the way back: the history the browser moves for it takes no page away,
    /// and going back over the fragment's entry moves the fragment again; back over the page's own entry is the
    /// way back.
    func testAFragmentMovedIsNoWayBack() throws {
        try WebBrowser.run("history.replaceState(null, '', location.pathname + location.search)")
        let host = WebRenderer.running { Text("Page") }
        var back = 0
        let listener = WebRelay.listener { back += 1 }
        defer {
            WebRelay.forget(listener)
            host.leave()
            try? WebBrowser.run("history.replaceState(null, '', location.pathname + location.search)")
        }
        WebRelay.listenToHistory(listener)
        WebRelay.pushHistory()

        try WebBrowser.run("location.hash = 'note/8'")
        for _ in 0..<10 { host.step() }
        XCTAssertEqual(back, 0, "a link, not the way back")

        try WebBrowser.run("history.back()")
        try settle(host) { try WebBrowser.evaluate("location.hash", on: 0) == nil }
        for _ in 0..<5 { host.step() }
        XCTAssertEqual(back, 0, "back over the fragment's entry moves the fragment again: no page goes")

        try WebBrowser.run("history.back()")
        try settle(host) { back > 0 }
        XCTAssertEqual(back, 1, "back over the page's own entry is the way back")
    }

    /// Steps the page until `done`, a few seconds at most.
    private func settle(_ host: WebRenderer, until done: () throws -> Bool) throws {
        for _ in 0..<100 {
            guard try !done() else { break }
            host.step()
        }
    }
}

/// What the linked application's window heard.
@MainActor
private final class Heard {
    var addresses: [String] = []
}

private struct LinkedApplication: Application {
    let heard: Heard

    var body: some Scene {
        let heard = self.heard
        return WindowGroup {
            Text("Links")
                .onLinkOpened { heard.addresses.append($0) }
        }
    }
}
