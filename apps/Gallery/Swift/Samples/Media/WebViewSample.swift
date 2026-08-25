import StateUI

/// MAUI: WebView.
struct WebViewSample: SampleContent {
    static let id = "webView"
    static let title = "WebView"
    static let summary = "A page of the web in the tree - fetched by URL, or HTML written in place."

    /// Held still: the web content scrolls ITSELF, and a page scroller above it
    /// would claim every drag - the rule every gesture sample follows.
    static let scrolls = false

    /// Each half is given the WINDOW's height: the web content scrolls itself,
    /// so a stated height would show the same sliver on every size of screen.
    static let fills = true

    /// Two halves that share nothing: the browser on a URL, and HTML written
    /// in place - each under a tab of its own, IN SWIFT after them.
    var parts: [SamplePart] {
        let browser = WebBrowserPart()
        let written = WrittenInPlacePart()

        return [SamplePart(title: "EXAMPLE 1", view: browser, notes: browser.words),
                SamplePart(title: "EXAMPLE 2", view: written, notes: written.words)]
    }

    /// Unused: `parts` above is what the page draws. Kept because the protocol
    /// asks for a `content` and these two halves have no single one.
    var content: Element {
        VStack {
            WebBrowserPart()
            WrittenInPlacePart()
        }
        .spacing(16)
    }

    static let code = """
        // -- EXAMPLE 1 --

        struct WebBrowserPart: ContentView {
            @State private var hasBack = false
            @State private var hasForward = false
            @State private var status = "nothing has loaded yet"
            @State private var answer = ""

            @State private var browser = ControlState<WebView>()

            var content: Element {
                Grid {
                    HStack {
                        Button("Back")
                            .isEnabled(hasBack)
                            .onClicked { try await browser.goBack() }

                        Button("Forward")
                            .isEnabled(hasForward)
                            .onClicked { try await browser.goForward() }

                        Button("Reload")
                            .onClicked { try await browser.reload() }
                    }
                    .gridRow(0)

                    // The browser takes the STAR row - as tall as the window
                    // leaves - and everything around it keeps its own height.
                    WebView("https://example.com")
                        .assign(browser)
                        // What the view calls itself to the server. Left
                        // unwritten it is the platform's own browser string.
                        .userAgent("StateUI Gallery")
                        .canGoBack($hasBack)
                        .canGoForward($hasForward)
                        .onNavigating { report in
                            status = "fetching \\(report.url)"
                        }
                        .onNavigated { report in
                            status = "\\(report.result): \\(report.url)"
                        }
                        // The platform killed the web content process and left
                        // the view blank. Nothing else reports it.
                        .onProcessTerminated {
                            status = "the web process died - press Reload"
                        }
                        .gridRow(1)

                    Label(status)
                        .gridRow(2)

                    Button("Title?")
                        .onClicked {
                            answer = try await browser.evaluateJavaScript("document.title")
                        }
                        .gridRow(3)

                    Label(answer)
                        .gridRow(4)
                }
                .rowDefinitions(.auto, .star, .auto, .auto, .auto)
            }
        }

        // -- EXAMPLE 2 --

        struct WrittenInPlacePart: ContentView {
            var content: Element {
                WebView()
                    .source(html: "<h2>Written in place</h2><p>No network involved.</p>")
            }
        }
        """
}

/// The browser half: a URL source, the platform's history reported into
/// bindings, and the four acts on the view's id.
private struct WebBrowserPart: ContentView {
    @State private var hasBack = false
    @State private var hasForward = false
    @State private var status = "nothing has loaded yet"
    @State private var answer = ""

    @State private var browser = ControlState<WebView>()

    var content: Element {
        Grid {
            HStack {
                Button("Back")
                    .isEnabled(hasBack)
                    .padding(14, 8)
                    .onClicked { try await browser.goBack() }

                Button("Forward")
                    .isEnabled(hasForward)
                    .padding(14, 8)
                    .onClicked { try await browser.goForward() }

                Button("Reload")
                    .padding(14, 8)
                    .onClicked { try await browser.reload() }
            }
            .spacing(8)
            .horizontalOptions(.center)
            .gridRow(0)

            // The browser takes the STAR row - as tall as the window leaves -
            // and everything around it keeps its own height.
            WebView("https://example.com")
                .assign(browser)
                // What the view calls itself to the server. Left unwritten it
                // is the platform's own browser string.
                .userAgent("StateUI Gallery")
                .canGoBack($hasBack)
                .canGoForward($hasForward)
                .onNavigating { report in
                    status = "fetching \(report.url)"
                }
                .onNavigated { report in
                    status = "\(report.result): \(report.url)"
                }
                // The platform killed the web content process and left the
                // view blank. Nothing else reports it.
                .onProcessTerminated {
                    status = "the web process died - press Reload"
                }
                .gridRow(1)

            Label(status)
                .fontSize(12)
                .fontFamily("Menlo")
                .textColor(Palette.accent)
                .gridRow(2)

            Button("Title?")
                .padding(14, 8)
                .horizontalOptions(.center)
                .onClicked {
                    answer = try await browser.evaluateJavaScript("document.title")
                }
                .gridRow(3)

            Label(answer)
                .fontSize(12)
                .textColor(Palette.subtle)
                .gridRow(4)
        }
        .rowDefinitions(.auto, .star, .auto, .auto, .auto)
        .rowSpacing(12)
    }

    var words: Element {
        VStack {
            Label("Follow the page's own link, and Back lights up: the two CanGo "
                + "properties are reported into bindings after every navigation, MAUI "
                + "giving neither an event. Back, Forward, Reload and the JavaScript "
                + "question are ACTS on the view's id, the way an animation is.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("The view also carries `.onProcessTerminated`, which no button here "
                + "can provoke: the platform runs web content in a process of "
                + "its own and kills that process when it runs out of memory, which "
                + "leaves the view BLANK with no navigation report to explain it. A "
                + "reader meets it on a phone with a heavy page open and the app left in "
                + "the background - and the recovery is `reload()`, which is what the "
                + "message it writes into the status says.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// The other shape of the same property: HTML written in the tree rather than
/// fetched - MAUI's HtmlWebViewSource. Nothing here touches the network.
private struct WrittenInPlacePart: ContentView {
    var content: Element {
        WebView()
            .source(html: "<h2>Written in place</h2><p>No network involved.</p>")
    }

    var words: Element {
        Label("The same property, the other shape: `source(html:)` is MAUI's "
            + "HtmlWebViewSource, shown without the network. The web content "
            + "scrolls itself, which is why this page holds still and each view "
            + "fills the height the window gives it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
