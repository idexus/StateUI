// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
@testable import StateUIWebViewWinUI
import StateUIConformance
import StateUIFoundation
import XCTest

/// The web view's backend on WinUI, registered as an application registers it: what WebView2 does that no family
/// asks.
final class WinUIWebViewTests: XCTestCase {
    override func setUp() {
        onUIThread { WinUIBackends.registered }
    }

    /// A document written in place with an address of its own stands at that address, which its relative links
    /// resolve against; nothing is fetched from it.
    func testADocumentWrittenInPlaceStandsAtItsOwnAddress() throws {
        try onUIThread {
            let (host, said) = try Self.asking(
                { WebView().source(html: "<p>Based</p>", baseURL: "https://example.invalid/dir/") },
                "document.body.innerText + ' ' + new URL('next', document.baseURI).href")
            XCTAssertEqual(said.values, ["Based https://example.invalid/dir/next"])
            _ = host
        }
    }

    /// A document written in place at an address of no path - no slash after its host - stands there too: WebView2
    /// asks for the address as it writes it, its path a slash, and the view answers that.
    func testADocumentAtAnAddressOfNoPathStandsThere() throws {
        try onUIThread {
            let (host, said) = try Self.asking(
                { WebView().source(html: "<p>Based</p>", baseURL: "https://Example.invalid") },
                "document.body.innerText + ' ' + location.href")
            XCTAssertEqual(said.values, ["Based https://example.invalid/"])
            _ = host
        }
    }

    /// Gone back to, a document written in place with no address of its own arrives again: WebView2 left a
    /// `data:` address it was sent to or taken back to unfinished, and every navigation after it.
    func testADocumentWrittenInPlaceIsGoneBackTo() throws {
        try onUIThread {
            let second = State(wrappedValue: false)
            let arrived = Received<String>()
            let web = Aim(WebView.self)
            let said = Received<String>()
            let host = WinUIRenderer.running {
                VStack {
                    WebView().source(html: second.wrappedValue ? "<p>Second</p>" : "<p>First</p>").aim(web)
                        .onNavigated { arrived.values.append("\($0.result)") }
                        .height(200)
                    Button("Back").onClicked(gate: .ignoreWhileRunning) { try await web.goBack() }.id("back")
                    Button("Ask").onClicked(gate: .ignoreWhileRunning) { said.values.append(try await web.evaluateJavaScript("document.body.innerText")) }
                }
            }
            Self.wait(host) { arrived.values.count == 1 }
            second.wrappedValue = true
            Self.wait(host) { arrived.values.count == 2 }
            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            Self.wait(host) { arrived.values.count == 3 }
            XCTAssertEqual(arrived.values, ["success", "success", "success"])

            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            Self.wait(host) { !said.values.isEmpty }
            XCTAssertEqual(said.values, ["First"])
        }
    }

    /// An agent taken away gives back the runtime's own, not the one last given.
    func testAnAgentTakenAwayGivesBackTheRuntimesOwn() throws {
        try onUIThread {
            let named = State<String?>(wrappedValue: "StateUI host")
            let arrived = Received<Bool>()
            let host = WinUIRenderer.running {
                VStack {
                    let web = WebView().source(html: "<p>First</p>").onNavigated { _ in arrived.values.append(true) }
                    (named.wrappedValue.map { web.userAgent($0) } ?? web).height(200)
                }
            }
            let web = try XCTUnwrap(host.views(WinUIHostedView<WinUIWebView>.self).first?.control)
            let agent = { web.read("agent") }
            Self.wait(host) { !arrived.values.isEmpty }
            XCTAssertEqual(agent(), "StateUI host")

            named.wrappedValue = nil
            Self.wait(host) { agent() != "StateUI host" }
            XCTAssertTrue(agent().contains("Mozilla"), agent())
        }
    }

    /// An agent given while WebView2 still comes - its page already asked for - is the one the page arrives asking
    /// as, not the one given with the page.
    func testAnAgentGivenBeforeWebView2StandsIsTheOneItAsksAs() throws {
        try onUIThread {
            let named = State(wrappedValue: "First agent")
            let arrived = Received<Bool>()
            let host = WinUIRenderer.running {
                WebView().source(html: "<p>First</p>").userAgent(named.wrappedValue)
                    .onNavigated { _ in arrived.values.append(true) }.height(200)
            }
            let web = try XCTUnwrap(host.views(WinUIHostedView<WinUIWebView>.self).first?.control)
            host.step()
            XCTAssertTrue(arrived.values.isEmpty, "WebView2 stood at once: nothing to prove")

            named.wrappedValue = "Second agent"
            host.step()
            Self.wait(host) { !arrived.values.isEmpty }
            XCTAssertEqual(web.read("agent"), "Second agent")
        }
    }

    /// A web view whose WebView2 cannot start - no runtime where its loader looks - tells its page failed, not a blank
    /// view and nothing.
    func testAWebViewWhoseRuntimeCannotStartTellsItsPageFailed() {
        onUIThread {
            _ = _putenv("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER=C:\\StateUI\\no-such-runtime")
            defer { _ = _putenv("WEBVIEW2_BROWSER_EXECUTABLE_FOLDER=") }
            let arrived = Received<WebNavigationResult>()
            let host = WinUIRenderer.running {
                WebView().source(html: "<p>First</p>").onNavigated { arrived.values.append($0.result) }.height(200)
            }
            Self.wait(host) { !arrived.values.isEmpty }
            XCTAssertEqual(arrived.values, [.failure])
        }
    }

    /// Documents written in place one after another - a preview written again as the user types - are served
    /// through one filter of the view's: WebView2 checks every request against every filter it holds.
    func testDocumentsWrittenInPlaceAreServedThroughOneFilter() throws {
        try onUIThread {
            let words = State(wrappedValue: "First")
            let arrived = Received<Bool>()
            let host = WinUIRenderer.running {
                WebView().source(html: "<p>\(words.wrappedValue)</p>").onNavigated { _ in arrived.values.append(true) }
                    .height(200)
            }
            let web = try XCTUnwrap(host.views(WinUIHostedView<WinUIWebView>.self).first?.control)
            for (count, next) in ["Second", "Third", "Fourth"].enumerated() {
                Self.wait(host) { arrived.values.count == count + 1 }
                words.wrappedValue = next
            }
            Self.wait(host) { arrived.values.count == 4 }
            XCTAssertEqual(web.read("filters"), "1")
        }
    }

    /// A web view an application listens to as a view stands, and its page arrives: WebView2, listened to by
    /// WinUI, ends the process - its page takes the user's hand.
    func testAWebViewListenedToStands() {
        onUIThread {
            let arrived = Received<Bool>()
            let host = WinUIRenderer.running {
                VStack {
                    WebView().source(html: "<p>First</p>").onTapped {}.onPointerEntered {}
                        .onNavigated { _ in arrived.values.append(true) }.height(200)
                }
            }
            Self.wait(host) { !arrived.values.isEmpty }
            XCTAssertEqual(arrived.values, [true])
        }
    }

    /// A page showing the web view `web` makes once it arrived, and what `script` answered in it.
    @MainActor private static func asking(
        _ web: @escaping @MainActor () -> WebView, _ script: String
    ) throws -> (WinUIRenderer, Received<String>) {
        let aim = Aim(WebView.self)
        let arrived = Received<Bool>()
        let said = Received<String>()
        let host = WinUIRenderer.running {
            VStack {
                web().aim(aim).onNavigated { _ in arrived.values.append(true) }.height(200)
                Button("Ask").onClicked(gate: .ignoreWhileRunning) { said.values.append(try await aim.evaluateJavaScript(script)) }
            }
        }
        wait(host) { !arrived.values.isEmpty }
        try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
        wait(host) { !said.values.isEmpty }
        return (host, said)
    }

    /// Steps the host until `done`, or twenty seconds: the web view's own processes take their time.
    @MainActor private static func wait(_ host: WinUIRenderer, until done: () -> Bool) {
        for _ in 0..<2000 where !done() { host.step() }
    }
}
