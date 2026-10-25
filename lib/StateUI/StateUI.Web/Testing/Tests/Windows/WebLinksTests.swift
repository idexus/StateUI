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
        return WindowGroup { Text("Links") }
            .onLinkOpened { heard.addresses.append($0) }
    }
}
