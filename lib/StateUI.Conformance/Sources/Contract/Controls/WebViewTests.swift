// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// `WebViewContract` on a host: a web view shows the page it is given, heard as it goes there and as it arrives;
/// the way back and forward heard as they open, and taken by its acts; a page loaded again; a script's answer; the
/// agent it names itself by; and the end of its content heard.
@_spi(Host) public enum WebViewTests: ConformanceFamily {
    public static let name = "WebView"

    public static var cases: [ConformanceCase] {
        [
            ConformanceCase("aPageIsHeardGoingAndArriving", covers: [
                Covered(WebViewContract.self), Covered(WebViewContract.source), Covered(WebViewContract.navigating),
                Covered(WebViewContract.navigated),
            ]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        WebView().source(html: Self.page("First"))
                            .onNavigating { heard.values.append("navigating \($0.event)") }
                            .onNavigated { heard.values.append("navigated \($0.result)") }
                            .height(200).id("web")
                    }
                }

                s.settle { heard.values.contains { $0.hasPrefix("navigated") } }
                s.expect(heard.values.last, "navigated success")
                s.expect(try s.held(WebViewContract.source, on: s.element("web")), .html(Self.page("First"), baseUrl: nil))
            },
            ConformanceCase("aScriptsAnswerComesBack", covers: [
                Covered(WebViewContract.evaluateJavaScript), Covered(WebViewContract.navigated), Covered(ButtonContract.clicked),
            ]) { s in
                let web = Aim(WebView.self)
                let said = Received<String>()
                let arrived = Received<Bool>()
                s.start {
                    VStack {
                        WebView().source(html: Self.page("First")).aim(web)
                            .onNavigated { _ in arrived.values.append(true) }.height(200).id("web")
                        Button("Ask").onClicked { said.values.append(try await web.evaluateJavaScript("1 + 1")) }.id("ask")
                    }
                }
                s.settle { !arrived.values.isEmpty }

                try s.perform(.activate, on: s.element("ask"))
                s.settle { !said.values.isEmpty }
                s.expect(said.values, ["2"])
            },
            ConformanceCase("theAgentItNamesItselfByIsTheTrees", covers: [
                Covered(WebViewContract.userAgent), Covered(WebViewContract.evaluateJavaScript),
                Covered(ButtonContract.clicked),
            ]) { s in
                let web = Aim(WebView.self)
                let said = Received<String>()
                let arrived = Received<Bool>()
                s.start {
                    VStack {
                        WebView().userAgent("StateUI conformance").source(html: Self.page("First")).aim(web)
                            .onNavigated { _ in arrived.values.append(true) }.height(200).id("web")
                        Button("Ask").onClicked {
                            said.values.append(try await web.evaluateJavaScript("navigator.userAgent"))
                        }.id("ask")
                    }
                }
                s.settle { !arrived.values.isEmpty }
                s.expect(try s.held(WebViewContract.userAgent, on: s.element("web")), "StateUI conformance")

                try s.perform(.activate, on: s.element("ask"))
                s.settle { !said.values.isEmpty }
                s.expect(said.values, ["StateUI conformance"])
            },
            ConformanceCase("theWayBackAndForwardOpenAndAreTaken", covers: [
                Covered(WebViewContract.canGoBackChanged), Covered(WebViewContract.canGoForwardChanged),
                Covered(WebViewContract.goBack), Covered(WebViewContract.goForward), Covered(ButtonContract.clicked),
            ]) { s in
                let web = Aim(WebView.self)
                let second = State(wrappedValue: false)
                let heard = Received<String>()
                s.start {
                    VStack {
                        WebView().source(html: Self.page(second.wrappedValue ? "Second" : "First")).aim(web)
                            .onEvent(WebViewContract.canGoBackChanged) { heard.values.append("back \($0)") }
                            .onEvent(WebViewContract.canGoForwardChanged) { heard.values.append("forward \($0)") }
                            .height(200).id("web")
                        Button("Second").onClicked { second.wrappedValue = true }.id("second")
                        Button("Back").onClicked { try await web.goBack() }.id("back")
                        Button("Forward").onClicked { try await web.goForward() }.id("forward")
                    }
                }

                try s.perform(.activate, on: s.element("second"))
                s.settle { heard.values.contains("back true") }
                s.expect(heard.values.contains("back true"), true, "the way back opened")

                try s.perform(.activate, on: s.element("back"))
                s.settle { heard.values.contains("forward true") }
                s.expect(heard.values.contains("forward true"), true, "taken back, the way forward opened")

                try s.perform(.activate, on: s.element("forward"))
                s.settle { heard.values.last == "forward false" }
                s.expect(heard.values.last, "forward false", "taken forward, the way forward closed")
            },
            ConformanceCase("aPageLoadedAgainIsHeard", covers: [
                Covered(WebViewContract.reload), Covered(WebViewContract.navigating), Covered(ButtonContract.clicked),
            ]) { s in
                let web = Aim(WebView.self)
                let heard = Received<WebNavigationEvent>()
                s.start {
                    VStack {
                        WebView().source(html: Self.page("First")).aim(web)
                            .onNavigating { heard.values.append($0.event) }.height(200).id("web")
                        Button("Reload").onClicked { try await web.reload() }.id("reload")
                    }
                }
                s.settle { !heard.values.isEmpty }

                try s.perform(.activate, on: s.element("reload"))
                s.settle { heard.values.count >= 2 }
                s.expect(heard.values.last, .refresh)
            },
            ConformanceCase("theEndOfItsContentIsHeard", covers: [Covered(WebViewContract.processTerminated)]) { s in
                let heard = Received<String>()
                s.start {
                    VStack {
                        WebView().source(html: Self.page("First"))
                            .onProcessTerminated { heard.values.append("ended") }.height(200).id("web")
                    }
                }

                try s.perform(.endContent, on: s.element("web"))
                s.settle { !heard.values.isEmpty }
                s.expect(heard.values, ["ended"])
            },
        ]
    }

    /// A page saying `words`.
    static func page(_ words: String) -> String {
        "<html><body><p>\(words)</p></body></html>"
    }
}
