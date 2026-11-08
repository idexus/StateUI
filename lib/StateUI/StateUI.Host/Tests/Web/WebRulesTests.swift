// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

@MainActor
final class WebRulesTests: XCTestCase {
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

    /// A step through the history the page takes goes back where it lands on a page of the way back, else forward.
    func testAStepThroughTheHistoryIsBackWhereItLandsBehind() {
        let behind = ["https://a.example/", "https://b.example/"]
        XCTAssertEqual(WebHistory.step(landingOn: "https://b.example/", behind: behind), .back)
        XCTAssertEqual(WebHistory.step(landingOn: "https://a.example/", behind: behind), .back)
        XCTAssertEqual(WebHistory.step(landingOn: "https://c.example/", behind: behind), .forward)
        XCTAssertEqual(WebHistory.step(landingOn: "https://c.example/", behind: []), .forward)
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
        cause.ask(.forward, if: true)
        XCTAssertEqual(cause.current, .newPage, "asked, not begun")
        XCTAssertEqual(cause.begin(told: .back), .forward)
        XCTAssertEqual(cause.current, .forward)
        XCTAssertEqual(cause.begin(told: .reload), .reload)
    }

    func testAQueuedStepDoesNotRewriteTheNavigationUnderWay() {
        var cause = WebNavigationCause()
        cause.ask(.back, if: true)
        XCTAssertEqual(cause.begin(told: .newPage), .back, "a toolkit need not tell a history step apart")
        cause.ask(.forward, if: true)
        XCTAssertEqual(cause.current, .back, "the accepted next step has not begun")
        XCTAssertEqual(cause.begin(told: .newPage), .forward)
    }

    func testAConsumedRequestDoesNotNameAnotherNativeNavigation() {
        var cause = WebNavigationCause()
        cause.ask(.reload, if: true)
        XCTAssertEqual(cause.begin(told: .newPage), .reload)
        XCTAssertEqual(cause.begin(told: .newPage), .newPage)
        XCTAssertEqual(cause.current, .newPage)
    }

    func testARefusedStepDoesNotNameTheNextNavigation() {
        for step in [WebNavigationKind.back, .forward, .reload] {
            var cause = WebNavigationCause()
            XCTAssertFalse(cause.ask(step, if: false))
            XCTAssertEqual(cause.begin(told: .newPage), .newPage)
        }
    }

    func testARefusedStepPreservesTheAcceptedOneStillWaiting() {
        var cause = WebNavigationCause()
        XCTAssertEqual(cause.begin(told: .newPage), .newPage)
        XCTAssertTrue(cause.ask(.back, if: true))
        XCTAssertFalse(cause.ask(.forward, if: false))
        XCTAssertEqual(cause.current, .newPage, "no new navigation has begun")
        XCTAssertEqual(cause.begin(told: .newPage), .back)
    }

    func testAnEmptyReloadSourceLeavesTheNativeDocumentInCharge() {
        var source = WebReloadSource()
        XCTAssertNil(source.value)
        source.committed()
        XCTAssertNil(source.value)
    }

    func testAReplacementKeepsItsCompleteDocumentAndBaseForReload() {
        var source = WebReloadSource()
        source.requested(.html("Previous", baseAddress: nil))
        let current = WebViewSource.html("Current", baseAddress: "https://stateui.invalid/")
        source.requested(current)
        XCTAssertEqual(source.value, current)
    }

    func testAnAuthoredDocumentWithABaseKeepsItsBytesAfterCommit() {
        var source = WebReloadSource()
        let document = WebViewSource.html("Current", baseAddress: "https://stateui.invalid/")
        source.requested(document)
        source.committed()
        source.committed()
        XCTAssertEqual(source.value, document)
    }

    func testAFetchedOrDataDocumentUsesNativeReloadAfterCommit() {
        for document in [WebViewSource.address("https://stateui.invalid/"), .html("Current", baseAddress: nil)] {
            var source = WebReloadSource()
            source.requested(document)
            XCTAssertEqual(source.value, document, "a request precedes the native document")
            source.committed()
            XCTAssertNil(source.value)
        }
    }

    func testANativeNavigationTakesOverFromTheAuthoredReloadSource() {
        var source = WebReloadSource()
        source.requested(.html("Current", baseAddress: "https://stateui.invalid/"))
        source.committed()
        source.takenOver()
        XCTAssertNil(source.value)
        let next = WebViewSource.address("https://next.invalid/")
        source.requested(next)
        XCTAssertEqual(source.value, next)
    }

    /// A document with no address of its own is gone to as a `data:` address holding it, its words in base64.
    func testADocumentWithNoAddressIsGoneToAsADataAddress() {
        XCTAssertEqual(WebDocument.address(of: "<p>Hi</p>"), "data:text/html;charset=utf-8;base64,PHA+SGk8L3A+")
        XCTAssertEqual(WebDocument.base64(Array("a".utf8)), "YQ==")
        XCTAssertEqual(WebDocument.base64(Array("ab".utf8)), "YWI=")
        XCTAssertEqual(WebDocument.base64(Array("żółw".utf8)), "xbzDs8WCdw==")
    }

    /// The document a view standing at such an address shows is read back from it; any other address holds none.
    func testADocumentIsReadBackFromItsDataAddress() {
        for document in ["<p>Hi</p>", "a", "ab", "abc", "żółw", ""] {
            XCTAssertEqual(WebDocument.document(at: WebDocument.address(of: document)), document, document)
        }
        XCTAssertNil(WebDocument.document(at: "https://example.com/"))
        XCTAssertNil(WebDocument.document(at: "about:blank"))
        XCTAssertNil(WebDocument.document(at: "data:text/plain;base64,YQ=="))
        XCTAssertNil(WebDocument.document(at: "data:text/html;charset=utf-8;base64,P*A+"), "no base64")
        XCTAssertNil(WebDocument.document(at: "data:text/html;charset=utf-8;base64,PHA"), "not whole groups of four")
    }

    /// A document written in place with an address of its own takes it as a `<base>` after its doctype: before it,
    /// a browser reads the document in quirks mode.
    func testTheBaseStandsAfterTheDoctype() {
        XCTAssertEqual(
            WebDocument.document("<!DOCTYPE html><html><body>Hi</body></html>", base: "https://example.com/docs/"),
            #"<!DOCTYPE html><base href="https://example.com/docs/"><html><body>Hi</body></html>"#)
        XCTAssertEqual(
            WebDocument.document("\n  <!doctype html>\n<p>Hi", base: "https://example.com/"),
            "\n  <!doctype html>" + #"<base href="https://example.com/">"# + "\n<p>Hi")
        XCTAssertEqual(
            WebDocument.document("<p>Hi</p>", base: #"https://example.com/?a=1&b="2""#),
            #"<base href="https://example.com/?a=1&amp;b=&quot;2&quot;"><p>Hi</p>"#, "a document of no doctype")
        XCTAssertEqual(WebDocument.document("<p>Hi</p>", base: nil), "<p>Hi</p>", "no address of its own")
    }
}
