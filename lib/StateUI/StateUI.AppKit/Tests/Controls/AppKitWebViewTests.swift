// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import WebKit
import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@_spi(Host) import StateUIApple
@_spi(Host) import StateUIConformance

@MainActor
final class AppKitWebViewTests: XCTestCase {
    func testAReloadWhileLoadingKeepsEveryKindOfCurrentSource() throws {
        let before = "<html><body>OLD_DOCUMENT</body></html>"
        let current = "<html><body>CURRENT_DOCUMENT</body></html>"
        let sources: [(String, StateUI.WebViewSource)] = [
            ("address", .address(WebDocument.address(of: current))),
            ("HTML without base", .html(current, baseAddress: nil)),
            ("HTML with base", .html(current, baseAddress: "file:///tmp/stateui-webkit-tests/")),
        ]
        for (kind, source) in sources {
            try Self.withPage { web, heard in
                web.show(.html(before, baseAddress: nil), userAgent: nil)
                try Self.wait(until: { !heard.arrived.isEmpty && !web.isLoading }, stage: "the preceding page")
                XCTAssertEqual(try Self.body(of: web), "OLD_DOCUMENT")

                let count = heard.arrived.count
                web.show(source, userAgent: nil)
                guard web.isLoading else {
                    return XCTFail("the replacement must still be loading before its reload: \(kind)")
                }
                web.step(.reload)
                try Self.wait(until: { heard.arrived.count > count && !web.isLoading }, stage: "the reloaded page")
                XCTAssertEqual(try Self.body(of: web), "CURRENT_DOCUMENT", kind)

                let afterReload = heard.arrived.count
                web.show(source, userAgent: nil)
                try Self.wait(until: { heard.arrived.count > afterReload && !web.isLoading }, stage: "the source control")
                XCTAssertEqual(try Self.body(of: web), "CURRENT_DOCUMENT", "the same source without an intervening reload")
            }
        }
    }

    func testAStepWithNoDestinationDoesNotNameTheNextNewPage() throws {
        for step in [StateUI.WebNavigationKind.back, .forward, .reload] {
            try Self.withPage { web, heard in
                XCTAssertFalse(web.canGoBack)
                XCTAssertFalse(web.canGoForward)
                web.step(step)
                web.show(.html("<html><body>FIRST_DOCUMENT</body></html>", baseAddress: nil), userAgent: nil)
                try Self.wait(until: { !heard.arrived.isEmpty && !web.isLoading }, stage: "the first page after \(step)")
                XCTAssertEqual(try Self.body(of: web), "FIRST_DOCUMENT")
                XCTAssertEqual(heard.began.last, .newPage, "a new source after \(step)")
                XCTAssertEqual(heard.arrived.last, .newPage, "the new source keeps its own cause to its end")
            }
        }
    }

    func testReloadAndHistoryFollowThePageVisitedNatively() throws {
        try Self.withPage { web, heard in
            web.show(.html("<html><body>AUTHORED_DOCUMENT</body></html>", baseAddress: nil), userAgent: nil)
            try Self.wait(until: { !heard.arrived.isEmpty && !web.isLoading }, stage: "the authored page")

            let visited = WebDocument.address(of: "<html><body>VISITED_DOCUMENT</body></html>")
            let address = try XCTUnwrap(URL(string: visited))
            let before = heard.arrived.count
            web.load(URLRequest(url: address))
            try Self.wait(until: { heard.arrived.count > before && !web.isLoading }, stage: "the native navigation")
            XCTAssertEqual(try Self.body(of: web), "VISITED_DOCUMENT")

            for (step, words) in [
                (StateUI.WebNavigationKind.reload, "VISITED_DOCUMENT"),
                (.back, "AUTHORED_DOCUMENT"), (.forward, "VISITED_DOCUMENT"),
            ] {
                if step == .back { XCTAssertTrue(web.canGoBack) }
                if step == .forward { XCTAssertTrue(web.canGoForward) }
                let count = heard.arrived.count
                web.step(step)
                try Self.wait(until: { heard.arrived.count > count && !web.isLoading }, stage: "the accepted \(step)")
                XCTAssertEqual(try Self.body(of: web), words)
                XCTAssertEqual(heard.began.last, step)
                XCTAssertEqual(heard.arrived.last, step)
            }
        }
    }

    func testReloadAfterCommitWhileResourcesLoadKeepsTheDocumentAndItsCause() throws {
        let driver = AppKitDriver()
        let address = try driver.served()
        let heldBefore = try driver.held().taken
        try Self.withPage { web, heard in
            let observer = CommitObserver(web)
            web.navigationDelegate = observer
            defer { web.navigationDelegate = web }
            web.show(.html("<html><body>OLD_DOCUMENT</body></html>", baseAddress: nil), userAgent: nil)
            try Self.wait(until: { !heard.arrived.isEmpty && !web.isLoading }, stage: "the preceding committed page")

            let commits = observer.commits
            let current = "<html><body>CURRENT_DOCUMENT<img src=\"\(address)/held\" width=\"1\" height=\"1\" alt=\"\"></body></html>"
            web.show(.html(current, baseAddress: address + "/document/"), userAgent: nil)
            try Self.wait(until: {
                observer.commits > commits && web.isLoading && ((try? driver.held().taken) ?? heldBefore) > heldBefore
            }, stage: "a committed main document with its loopback resource still loading")
            XCTAssertEqual(try Self.body(of: web), "CURRENT_DOCUMENT")
            XCTAssertTrue(web.isLoading, "the delayed resource keeps the committed document loading")

            let began = heard.began.count
            let arrived = heard.arrived.count
            web.step(.reload)
            try Self.wait(until: { heard.arrived.count > arrived && !web.isLoading }, stage: "reload after commit")
            XCTAssertEqual(try Self.body(of: web), "CURRENT_DOCUMENT")
            XCTAssertGreaterThan(heard.began.count, began, "reload starts its own navigation")
            XCTAssertEqual(heard.began.last, .reload)
            XCTAssertEqual(heard.arrived.last, .reload)

            let reloaded = heard.arrived.count
            web.show(.html("<html><body>NEXT_DOCUMENT</body></html>", baseAddress: nil), userAgent: nil)
            try Self.wait(until: { heard.arrived.count > reloaded && !web.isLoading }, stage: "the source after reload")
            XCTAssertEqual(try Self.body(of: web), "NEXT_DOCUMENT")
            XCTAssertEqual(heard.began.last, .newPage)
            XCTAssertEqual(heard.arrived.last, .newPage)
        }
    }

    /// A script's answer JSON cannot say - not a number, a date - reads as nothing and never stops the application;
    /// words and numbers read as JSON writes them.
    func testAScriptsAnswerThatIsNoJSONReadsAsNothing() throws {
        try Self.withPage { web, heard in
            web.show(.html("<html><body>PAGE</body></html>", baseAddress: nil), userAgent: nil)
            try Self.wait(until: { !heard.arrived.isEmpty && !web.isLoading }, stage: "the page")

            var answers: [String: String?] = [:]
            for script in ["0/0", "new Date(0)", "'words'", "1.5"] {
                web.evaluate(script) { answers[script] = .some($0) }
            }
            try Self.wait(until: { answers.count == 4 }, stage: "the answers")
            XCTAssertEqual(answers["0/0"], .some(nil))
            XCTAssertEqual(answers["new Date(0)"], .some(nil))
            XCTAssertEqual(answers["'words'"], "words")
            XCTAssertEqual(answers["1.5"], "1.5")
        }
    }

    private static func withPage(_ body: @MainActor (WebKitView, Heard) throws -> Void) rethrows {
        _ = NSApplication.shared
        let web = WebKitView()
        let heard = Heard()
        web.onNavigating = { kind, _ in heard.began.append(kind) }
        web.onNavigated = { result, kind, _ in
            if result == .success { heard.arrived.append(kind) }
        }
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 200),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = web
        defer {
            web.onNavigating = nil
            web.onNavigated = nil
            web.stopLoading()
            window.contentView = nil
            window.close()
        }
        try body(web, heard)
    }

    private static func body(of web: WKWebView) throws -> String {
        var answered = false
        var text: String?
        var failure: (any Error)?
        web.evaluateJavaScript("document.body.innerText") { value, error in
            text = value as? String
            failure = error
            answered = true
        }
        try wait(until: { answered }, stage: "the page's body")
        if let failure { throw failure }
        return try XCTUnwrap(text, "the native page answers its actual body text")
    }

    private static func wait(until ready: () -> Bool, stage: String) throws {
        let end = Date().addingTimeInterval(20)
        while !ready(), Date() < end {
            _ = RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }
        guard ready() else { throw WaitFailure(stage: stage) }
    }

    @MainActor private final class Heard {
        var began: [StateUI.WebNavigationKind] = []
        var arrived: [StateUI.WebNavigationKind] = []
    }

    private struct WaitFailure: Error {
        let stage: String
    }

    @MainActor
    private final class CommitObserver: NSObject, WKNavigationDelegate {
        let target: WebKitView
        var commits = 0
        init(_ target: WebKitView) { self.target = target }

        func webView(_ web: WKWebView, decidePolicyFor action: WKNavigationAction,
                     decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void) {
            target.webView(web, decidePolicyFor: action, decisionHandler: decisionHandler)
        }
        func webView(_ web: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            target.webView(web, didStartProvisionalNavigation: navigation)
        }
        func webView(_ web: WKWebView, didCommit navigation: WKNavigation?) {
            target.webView(web, didCommit: navigation)
            commits += 1
        }
        func webView(_ web: WKWebView, didFinish navigation: WKNavigation?) {
            target.webView(web, didFinish: navigation)
        }
        func webView(_ web: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
            target.webView(web, didFail: navigation, withError: error)
        }
        func webView(_ web: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: any Error) {
            target.webView(web, didFailProvisionalNavigation: navigation, withError: error)
        }
        func webViewWebContentProcessDidTerminate(_ web: WKWebView) {
            target.webViewWebContentProcessDidTerminate(web)
        }
    }
}
#endif
