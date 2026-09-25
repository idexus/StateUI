// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

final class WinUILabelViewTests: XCTestCase {
    /// A label's words take the font, the colour, the lines and the alignment the tree gives them.
    func testALabelTakesItsFontColourLinesAndAlignment() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Label("words")
                        .fontSize(20)
                        .fontAttributes(.bold)
                        .textColor(Color("#FF0000"))
                        .maximumLines(2)
                        .horizontalTextAlignment(.center)
                }
            }
            let style = try XCTUnwrap(host.views(WinUILabelView.self).first).wordsStyle

            XCTAssertEqual(style.size, 20)
            XCTAssertEqual(style.weight, 700, "bold")
            XCTAssertEqual(style.lines, 2)
            XCTAssertEqual(style.alignment, 0, "WinUI's TextAlignment.Center")
            XCTAssertEqual(style.color, 0xFFFF_0000)
        }
    }

    /// A label with nothing said stands as WinUI's own body text, in the theme's colour.
    func testALabelWithNothingSaidIsWinUIsOwnText() throws {
        try onUIThread {
            let host = WinUIRenderer.running { VStack { Label("plain") } }
            let style = try XCTUnwrap(host.views(WinUILabelView.self).first).wordsStyle

            XCTAssertEqual(style.size, WinUITextView.platformFontSize)
            XCTAssertEqual(style.weight, 400)
        }
    }
}
