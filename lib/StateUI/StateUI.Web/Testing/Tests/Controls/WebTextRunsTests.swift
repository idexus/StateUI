// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWeb
import XCTest

/// A text's runs over its own look: a line under a node is drawn under all it holds and no run could take it away,
/// so while runs show, the text's lines stand on each run that does not say its own.
@MainActor
final class WebTextRunsTests: XCTestCase {
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
        text.setRuns(nil, over: label)
        XCTAssertEqual(text.styled("text-decoration-line"), "underline", "its own words again")
    }
}
