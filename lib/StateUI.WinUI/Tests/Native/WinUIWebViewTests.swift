// SPDX-FileCopyrightText: 2026 PaweÅ‚ KrzywdziÅ„ski and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIWinUI
import StateUIConformance
import XCTest

final class WinUIWebViewTests: XCTestCase {
    /// A document written in place with an address of its own stands at that address, which its relative links
    /// resolve against; nothing is fetched from it.
    func testADocumentWrittenInPlaceStandsAtItsOwnAddress() throws {
        try onUIThread {
            let (host, said) = try Self.asking(
                { WebView().source(html: "<p>Based</p>", baseUrl: "https://example.invalid/dir/") },
                "document.body.innerText + ' ' + new URL('next', document.baseURI).href")
            XCTAssertEqual(said.values, ["Based https://example.invalid/dir/next"])
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
                    Button("Back").onClicked { try await web.goBack() }.id("back")
                    Button("Ask").onClicked { said.values.append(try await web.evaluateJavaScript("document.body.innerText")) }
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
            let web = try XCTUnwrap(host.views(WinUIWebView.self).first)
            let agent = { WinUIStrings.read { stateui_winui_web_read(web.handle, web.number, "agent", $0, $1) } }
            Self.wait(host) { !arrived.values.isEmpty }
            XCTAssertEqual(agent(), "StateUI host")

            named.wrappedValue = nil
            Self.wait(host) { agent() != "StateUI host" }
            XCTAssertTrue(agent().contains("Mozilla"), agent())
        }
    }

    /// A web view an application listens to as a view stands, and its page arrives: WebView2, listened to by
    /// WinUI, ends the process - its page takes the user's hand.
    func testAWebViewListenedToStands() throws {
        try onUIThread {
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
        _ web: @escaping @Sendable () -> WebView, _ script: String
    ) throws -> (WinUIRenderer, Received<String>) {
        let aim = Aim(WebView.self)
        let arrived = Received<Bool>()
        let said = Received<String>()
        let host = WinUIRenderer.running {
            VStack {
                web().aim(aim).onNavigated { _ in arrived.values.append(true) }.height(200)
                Button("Ask").onClicked { said.values.append(try await aim.evaluateJavaScript(script)) }
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
