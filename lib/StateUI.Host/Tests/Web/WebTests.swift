// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

final class WebTests: XCTestCase {
    /// A script's answer is its words as they are, a number as it is written, anything else as JSON; nothing for no
    /// value.
    func testAScriptsAnswerIsItsValueAsText() {
        XCTAssertEqual(ScriptAnswer.text(json: "2"), "2")
        XCTAssertEqual(ScriptAnswer.text(json: "1.5"), "1.5")
        XCTAssertEqual(ScriptAnswer.text(json: "\"StateUI conformance\""), "StateUI conformance")
        XCTAssertEqual(ScriptAnswer.text(json: #""a \"b\"\ną 👋""#), "a \"b\"\n\u{105} 👋")
        XCTAssertEqual(ScriptAnswer.text(json: #"{"a":[1,true]}"#), #"{"a":[1,true]}"#)
        XCTAssertEqual(ScriptAnswer.text(json: "true"), "true")
        XCTAssertNil(ScriptAnswer.text(json: "null"))
        XCTAssertNil(ScriptAnswer.text(json: nil))
        XCTAssertNil(ScriptAnswer.text(json: ""))
    }

    /// A way back or forward is said only as it changes.
    func testAWayIsSaidOnlyAsItChanges() {
        var history = WebHistory()
        XCTAssertTrue(history.changes(back: false, forward: false) == (nil, nil))
        XCTAssertTrue(history.changes(back: true, forward: false) == (true, nil))
        XCTAssertTrue(history.changes(back: true, forward: false) == (nil, nil))
        XCTAssertTrue(history.changes(back: false, forward: true) == (false, true))
    }

    /// A navigation begins for the step the program asked for, else for what the platform tells, and keeps its cause
    /// to its end; the next begins for what is told.
    func testANavigationBeginsForTheStepAskedElseWhatIsTold() {
        var cause = WebNavigationCause()
        XCTAssertEqual(cause.begin(told: .newPage), .newPage)
        cause.ask(.forward)
        XCTAssertEqual(cause.current, .newPage, "asked, not begun")
        XCTAssertEqual(cause.begin(told: .back), .forward)
        XCTAssertEqual(cause.current, .forward)
        XCTAssertEqual(cause.begin(told: .refresh), .refresh)
    }
}
