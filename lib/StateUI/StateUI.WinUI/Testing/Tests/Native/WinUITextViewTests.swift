// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
import XCTest

/// One label, its words in spans until a button takes them away.
private struct SpannedPage: View {
    @State private var spanned = true

    var body: some View {
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
    /// Words offered their own width keep their lines at every scale: WinUI lays a TextBlock out on whole pixels,
    /// and its width read back through a 32-bit float can stand a pixel short of the words - at 125% a sentence of
    /// the Gallery broke in two there, and its layout measured it again at every pass until WinUI ended the process.
    /// Design: docs/design/host/layout.md#words-in-a-wider-room
    func testWordsOfferedTheirOwnWidthKeepTheirLines() {
        onUIThread {
            let sentences = [
                "Scroll to the end, tap a row to choose it, and rotate the rows one place either way.",
                "Swipe both strips: the cards share one width, and every tag is as wide as its word.",
                "Only the items on screen are built - down, across, in columns or in groups.",
                "That is all of them.", "N and N², a thousand times", "Tap a row.",
            ]
            let sizes = [11.0, 12, 13, 14, 15, 17]
            let words = Array(sizes.flatMap { size in sentences.map { ($0, size) } }.enumerated())
            let host = WinUIRenderer.running {
                VStack {
                    ForEach(words, id: \.offset) { Text($0.element.0).fontSize($0.element.1) }
                }
            }
            host.layOut()

            let texts = host.views(WinUITextView.self)
            XCTAssertEqual(texts.count, sentences.count * sizes.count)
            for text in texts {
                let natural = text.measure(width: nil, height: nil)
                let again = text.measure(width: natural.width, height: nil)
                XCTAssertEqual(again.height, natural.height, accuracy: 0.01, "\(text.text) offered \(natural.width)")
            }
        }
    }

    /// A label with nothing said stands as WinUI's own body text, in the theme's color.
    func testATextWithNothingSaidIsWinUIsOwnText() throws {
        try onUIThread {
            let host = WinUIRenderer.running { VStack { Text("plain") } }
            let style = try XCTUnwrap(host.views(WinUITextView.self).first).wordsStyle

            XCTAssertEqual(style.size, WinUITextualView.platformFontSize)
            XCTAssertEqual(style.weight, 400)
        }
    }

    /// Numbers past what WinUI counts - its thousandths of an em between letters, a label's lines, the floats its
    /// layout places by - stop nothing: the words stand with no room between their letters and no bound on their
    /// lines, and a stack a padding past a pixel's reach widens places its stepper as none.
    func testNumbersPastWhatWinUICountsStopNothing() throws {
        onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Text("Spaced").tracking(1e300)
                    Text("Run").spans { TextSpan("spaced").tracking(-1e300) }
                    Text("Lines").maximumLines(3_000_000_000)
                    Text("Padded").padding(Insets(1e300))
                    Button("Pressed").tracking(1e300)
                    Stepper(1)
                }
            }
            host.settle { false }

            XCTAssertEqual(host.views(WinUITextView.self).count, 4)
            XCTAssertEqual(host.views(WinUIButtonView.self).count, 1)
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
