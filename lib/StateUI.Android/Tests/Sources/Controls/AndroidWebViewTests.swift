// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIAndroid
import XCTest

final class AndroidWebViewTests: XCTestCase {
    static var allTests: [(String, (AndroidWebViewTests) -> () throws -> Void)] {
        [
            ("testWhatThePageDoesArrivesAsTheViewsEvents", testWhatThePageDoesArrivesAsTheViewsEvents),
            ("testAHistoryFlagIsSaidWhenItChanges", testAHistoryFlagIsSaidWhenItChanges),
            ("testAScriptsValueAnswersAsText", testAScriptsValueAnswersAsText),
        ]
    }

    /// A navigation starting and ending, and why - a reload says so - how one that timed out ended, and the web
    /// process dying, each as Android's client hears it.
    func testWhatThePageDoesArrivesAsTheViewsEvents() throws {
        try onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running { BrowsingPage(heard: heard) }
            let web = try XCTUnwrap(host.views(AndroidWebView.self).first)

            TestWeb.start(web, at: "https://a.example/")
            TestWeb.finish(web, at: "https://a.example/")
            try XCTUnwrap(host.views(AndroidButtonView.self).first).click()
            host.pump()
            TestWeb.start(web, at: "https://a.example/")
            Java.call(web.reference, TestWeb.failed, .int(-8))
            TestWeb.finish(web, at: "https://a.example/")
            Java.call(web.reference, TestWeb.processGone)
            host.pump()

            XCTAssertEqual(heard.values, [
                "navigating newPage https://a.example/", "navigated success newPage https://a.example/",
                "navigating refresh https://a.example/", "navigated timeout refresh https://a.example/",
                "gone",
            ])
        }
    }

    /// Whether there is a page behind and ahead reaches its binding when it changes, and only then.
    func testAHistoryFlagIsSaidWhenItChanges() throws {
        try onMainActor {
            let heard = Received<String>()
            let host = AndroidRenderer.running { BrowsingPage(heard: heard) }
            let web = try XCTUnwrap(host.views(AndroidWebView.self).first)

            web.history(back: true, forward: false)
            web.history(back: true, forward: false)
            web.history(back: false, forward: true)
            host.pump()

            XCTAssertEqual(heard.values, ["back true", "back false", "forward true"])
        }
    }

    /// A script's value is text: a string as itself, none for null, anything else as JSON writes it; the act
    /// waits under its ticket and answers with it.
    func testAScriptsValueAnswersAsText() throws {
        try onMainActor {
            XCTAssertEqual(TestWeb.text("\"Example \\\"Domain\\\"\""), "Example \"Domain\"")
            XCTAssertNil(TestWeb.text("null"))
            XCTAssertEqual(TestWeb.text("42"), "42")
            XCTAssertEqual(TestWeb.text("{\"a\":1}"), "{\"a\":1}")

            let heard = Received<String>()
            let host = AndroidRenderer.running { BrowsingPage(heard: heard) }
            try XCTUnwrap(host.views(AndroidButtonView.self).last).click()
            host.pump()
            host.answered(ticket: AndroidActPerformer.nextTicket - 1, accepted: true, words: "Example Domain")
            host.settle { heard.values.contains { $0.hasPrefix("title") } }

            XCTAssertEqual(heard.values, ["title Example Domain"])
        }
    }
}

/// A web view, aimed at, with a button that loads it again and one that asks its page's title.
private struct BrowsingPage: ContentView {
    @Aim(WebView.self) private var browser
    @State private var back = false
    @State private var forward = false
    let heard: Received<String>

    var content: any View {
        let browser = self.browser
        let heard = self.heard
        return VStack {
            WebView().source(html: "<p>Written</p>")
                .aim(browser)
                .canGoBack($back)
                .canGoForward($forward)
                .onNavigating { heard.values.append("navigating \($0.event) \($0.url)") }
                .onNavigated { heard.values.append("navigated \($0.result) \($0.event) \($0.url)") }
                .onProcessTerminated { heard.values.append("gone") }
                .height(200)
            Button("Reload").onClicked { try await browser.reload() }
            Button("Title?").onClicked {
                let title = try await browser.evaluateJavaScript("document.title")
                heard.values.append("title \(title)")
            }
        }
        .onChanged(back) { heard.values.append("back \(back)") }
        .onChanged(forward) { heard.values.append("forward \(forward)") }
    }
}

/// What Android's web client tells `StateUIWebView`, told it by hand: the page's own callbacks run on the UI
/// thread only once a test has ended.
@MainActor
enum TestWeb {
    private static let started = Java.method(JavaAPI.webView, "started", "(Ljava/lang/String;)V")
    private static let finished = Java.method(JavaAPI.webView, "finished", "(Ljava/lang/String;)V")
    static let failed = Java.method(JavaAPI.webView, "failed", "(I)V")
    static let processGone = Java.method(JavaAPI.webView, "processGone", "()V")
    private static let textOf = Java.staticMethod(JavaAPI.webView, "text", "(Ljava/lang/String;)Ljava/lang/String;")

    /// A navigation to `address` started.
    static func start(_ web: AndroidWebView, at address: String) {
        Java.frame { Java.call(web.reference, started, .object(Java.string(address))) }
    }

    /// The navigation to `address` ended.
    static func finish(_ web: AndroidWebView, at address: String) {
        Java.frame { Java.call(web.reference, finished, .object(Java.string(address))) }
    }

    static func text(_ json: String) -> String? {
        Java.frame {
            Java.callStaticObject(JavaAPI.webView, textOf, .object(Java.string(json))).map { Java.text($0) }
        }
    }
}
