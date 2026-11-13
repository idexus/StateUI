// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A text's runs over its own look: a line under a node is drawn under all it holds and no run could take it away,
/// so while runs show, the text's lines stand on each run that does not say its own. A host runs in the page, so the
/// suite runs it in a browser (`test-web.sh --browser`).
@MainActor
final class WebTextRunsTests: XCTestCase {
    override func setUp() async throws {
        WebTestLoop.started
    }

    func testARunGivenNoLinesStandsSoInAnUnderlinedText() {
        var label = TextLook()
        label.decorations = .underline
        label.decorationsGiven = true
        var plain = TextLook()
        plain.decorationsGiven = true
        let text = WebTextView()
        defer { text.release() }

        text.setSpacing(label)
        XCTAssertEqual(text.styled("text-decoration-line"), "underline", "the text's own words, underlined")
        text.setRuns([TextRun(text: "plain", look: plain), TextRun(text: "said", look: TextLook())], over: label)
        let spans = text.runSpans

        XCTAssertNil(text.styled("text-decoration-line"), "no line under the runs as a whole")
        XCTAssertEqual(spans.map { $0.styled("text-decoration-line") }, [nil, "underline"])
        text.setSpacing(label)
        XCTAssertNil(text.styled("text-decoration-line"), "nor after the text's look is written again")
        var struck = TextLook()
        struck.decorations = .strikethrough
        text.setSpacing(struck)
        XCTAssertEqual(spans.map { $0.styled("text-decoration-line") }, [nil, "line-through"], "the text's lines now")
        text.setSpacing(TextLook())
        XCTAssertEqual(spans.map { $0.styled("text-decoration-line") }, [nil, nil], "and none")
        text.setSpacing(label)
        text.setRuns(nil, over: label)
        XCTAssertEqual(text.styled("text-decoration-line"), "underline", "its own words again")
    }

    /// The text's lines driven by a state, no body built again, reach its runs: one saying none of its own takes the
    /// lines as they now stand, one saying none keeps none.
    func testATextsLinesDrivenByAStateReachItsRuns() throws {
        let lines = State(wrappedValue: TextDecorations.underline)
        let host = WebRenderer.running {
            VStack {
                Text("")
                    .textDecorations(lines.projectedValue)
                    .spans {
                        TextSpan("takes")
                        TextSpan("plain").textDecorations([])
                    }
            }
        }
        defer { host.finish() }
        host.step()
        let text = try XCTUnwrap(host.views(WebTextView.self).first)
        let shown = { text.runSpans.map { $0.styled("text-decoration-line") } }
        XCTAssertEqual(shown(), ["underline", nil])

        lines.wrappedValue = .strikethrough
        host.step()
        XCTAssertEqual(shown(), ["line-through", nil], "the lines the state now says")

        lines.wrappedValue = []
        host.step()
        XCTAssertEqual(shown(), [nil, nil], "and none")
        XCTAssertNil(text.styled("text-decoration-line"), "none under the runs as a whole")
    }
}
