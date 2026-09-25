// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// A word whose colour a button changes.
private struct ChangingRunPage: ContentView {
    @State private var red = true

    var content: any View {
        VStack {
            Label().spans { TextSpan("word").textColor(red ? Color("#FF0000") : Color("#0000FF")) }
            Button("Blue").onClicked { red = false }
        }
    }
}

/// One label, its words in spans until a button takes them away.
private struct SpannedPage: ContentView {
    @State private var spanned = true

    var content: any View {
        VStack {
            if spanned {
                Label("own").spans { TextSpan("runs") }.id("words")
            } else {
                Label("own").id("words")
            }
            Button("Plain").onClicked { spanned = false }
        }
    }
}

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

    /// A label's spans are its words, run by run, each in its own colour, size, weight, lines and background.
    func testALabelsSpansAreItsWordsRunByRun() throws {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Label()
                        .spans {
                            TextSpan("let ").textColor(Color("#FF0000"))
                            TextSpan("x").fontSize(20).fontAttributes([.bold, .italic])
                            TextSpan(" = 1").textDecorations(.underline).background(Color("#FFFF00"))
                        }
                }
            }
            let label = try XCTUnwrap(host.views(WinUILabelView.self).first)

            XCTAssertEqual(label.text, "let x = 1")
            XCTAssertEqual(label.runs, [
                [0xFFFF_0000, 0, 400, 0, 0, 0],
                [0, 20, 700, 1, 0, 0],
                [0, 0, 400, 0, 1, 0xFFFF_FF00],
            ])
        }
    }

    /// A span that changes changes its run.
    func testASpanThatChangesChangesItsRun() throws {
        try onUIThread {
            let host = WinUIRenderer.running { ChangingRunPage() }
            let label = try XCTUnwrap(host.views(WinUILabelView.self).first)
            XCTAssertEqual(label.runs.first?.first, 0xFFFF_0000)

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()

            XCTAssertEqual(label.runs.first?.first, 0xFF00_00FF)
        }
    }

    /// A label whose spans are taken away shows its own words again.
    func testALabelWithoutItsSpansShowsItsOwnWords() throws {
        try onUIThread {
            let host = WinUIRenderer.running { SpannedPage() }
            let label = try XCTUnwrap(host.views(WinUILabelView.self).first)
            XCTAssertEqual(label.text, "runs")

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()

            XCTAssertTrue(host.views(WinUILabelView.self).first === label, "the same label, its spans gone")
            XCTAssertEqual(label.text, "own")
        }
    }
}

private extension WinUILabelView {
    /// The runs WinUI shows: each run's colour, size, weight, italic, lines and background.
    var runs: [[Double]] {
        var values = [Double](repeating: 0, count: 6 * 16)
        let count = Int(stateui_winui_text_runs(handle, &values, Int32(values.count)))
        return (0..<min(count, 16)).map { Array(values[6 * $0..<6 * $0 + 6]) }
    }
}
