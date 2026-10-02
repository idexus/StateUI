// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

/// One label, its words in spans until a button takes them away.
private struct SpannedPage: ContentView {
    @State private var spanned = true

    var content: some View {
        VStack {
            if spanned {
                Text("own").spans { TextSpan("runs") }.id("words")
            } else {
                Text("own").id("words")
            }
            Button("Plain").onClicked { spanned = false }
        }
    }
}

final class WinUITextViewTests: XCTestCase {
    /// A label with nothing said stands as WinUI's own body text, in the theme's colour.
    func testATextWithNothingSaidIsWinUIsOwnText() throws {
        try onUIThread {
            let host = WinUIRenderer.running { VStack { Text("plain") } }
            let style = try XCTUnwrap(host.views(WinUITextView.self).first).wordsStyle

            XCTAssertEqual(style.size, WinUITextualView.platformFontSize)
            XCTAssertEqual(style.weight, 400)
        }
    }

    /// A label whose spans are taken away shows its own words again.
    func testATextWithoutItsSpansShowsItsOwnWords() throws {
        try onUIThread {
            let host = WinUIRenderer.running { SpannedPage() }
            let label = try XCTUnwrap(host.views(WinUITextView.self).first)
            XCTAssertEqual(label.text, "runs")

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()

            XCTAssertTrue(host.views(WinUITextView.self).first === label, "the same label, its spans gone")
            XCTAssertEqual(label.text, "own")
        }
    }
}
