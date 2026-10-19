// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
@testable import StateUIWebViewGTK
import StateUIConformance
import XCTest

/// The web view's backend on GTK, registered as an application registers it: what WebKitGTK does that no family asks.
final class GTKWebViewTests: XCTestCase {
    override func setUp() {
        onUIThread { GTKBackends.registered }
    }

    /// A step through the history the page takes itself is told as the way it goes - back, then forward - by where it
    /// lands among WebKit's pages behind.
    func testAStepThePageTakesIsToldItsWay() throws {
        try onUIThread {
            let second = State(wrappedValue: false)
            let web = Aim(WebView.self)
            let heard = Received<String>()
            let arrived = Received<Bool>()
            let host = GTKRenderer.running {
                VStack {
                    WebView().source(html: second.wrappedValue ? "<p>Second</p>" : "<p>First</p>").aim(web)
                        .onNavigating { heard.values.append("\($0.type)") }
                        .onNavigated { _ in arrived.values.append(true) }
                        .height(200)
                    Button("Back").onClicked(gate: .ignoreWhileRunning) {
                        _ = try await web.evaluateJavaScript("history.back()")
                    }
                    Button("Forward").onClicked(gate: .ignoreWhileRunning) {
                        _ = try await web.evaluateJavaScript("history.forward()")
                    }
                }
            }
            Self.wait(host) { arrived.values.count == 1 }
            second.wrappedValue = true
            Self.wait(host) { arrived.values.count == 2 }
            heard.values = []

            try XCTUnwrap(host.views(GTKButtonView.self).first).click()
            Self.wait(host) { !heard.values.isEmpty }
            try XCTUnwrap(host.views(GTKButtonView.self).last).click()
            Self.wait(host) { heard.values.count == 2 }

            XCTAssertEqual(heard.values, ["back", "forward"])
        }
    }

    /// Steps the host until `done`, or twenty seconds: WebKit's own processes take their time.
    @MainActor private static func wait(_ host: GTKRenderer, until done: () -> Bool) {
        for _ in 0..<2000 where !done() { host.step() }
    }
}
