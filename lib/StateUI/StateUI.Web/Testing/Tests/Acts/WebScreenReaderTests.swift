// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWeb
import XCTest

/// What the screen reader is told, as the page's live region says it. The browser says it, so the suite runs it in
/// one (`test-web.sh --browser`).
@MainActor
final class WebScreenReaderTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    /// The words told are the words asked, though made as the program runs and gone from its memory before the region
    /// says them: short words, which a string holds in itself, and longer ones, which it holds apart.
    func testTheWordsToldAreTheWordsAsked() throws {
        for count in [1, 6] {
            tell(count)
            // The program goes on, writing over the memory the words stood in.
            let written = (0..<64).map { String(repeating: "X", count: $0 % 30 + 1) + "\($0)" }
            XCTAssertEqual(written.count, 64)
            var said = ""
            for _ in 0..<30 where said.isEmpty {
                WebBrowser.pause()
                said = try WebBrowser.evaluate("document.getElementById('stateui-announcer').textContent", on: 0) ?? ""
            }
            XCTAssertEqual(said, String(repeating: "Saved ", count: count) + "\(count)")
        }
    }

    /// Tells the screen reader words made here, which go as the function returns.
    private func tell(_ count: Int) {
        WebRelay.announce(String(repeating: "Saved ", count: count) + "\(count)")
    }
}
