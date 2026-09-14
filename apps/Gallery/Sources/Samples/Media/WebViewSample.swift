import StateUI

/// A page of the web: fetched by URL, and HTML written in place.
struct WebViewSample: SampleContent {
    static let id = "webView"
    static let title = "WebView"
    static let summary = "A page of the web in the tree - fetched by URL, or HTML written in place."

    /// Held still: the web content scrolls ITSELF, and a page scroller above it
    /// would claim every drag - the rule every gesture sample follows.
    static let scrolls = false

    /// Each example is given the WINDOW's height: the web content scrolls
    /// itself, so a stated height would show the same sliver on every size of
    /// screen.
    static let fills = true

    var examples: [Example] {
        [Example(WebBrowserPart()), Example(WrittenInPlacePart())]
    }
}

/// The browser: a URL source, the platform's history reported into bindings,
/// and the four acts aimed at the view with `@Aim`.
private struct WebBrowserPart: ExampleContent {
    @State private var hasBack = false
    @State private var hasForward = false
    @State private var status = "nothing has loaded yet"
    @State private var answer = ""

    @Aim(WebView.self) private var browser

    static let code = """
        struct WebBrowserPart: ContentView {
            @State private var hasBack = false
            @State private var hasForward = false
            @State private var status = "nothing has loaded yet"
            @State private var answer = ""

            @Aim(WebView.self) private var browser

            var content: any View {
                Grid {
                    HStack {
                        // The history flags are read by this bar, so every
                        // page that loads builds this closure.
                        DebugInfoLabel()

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
                        .aim(browser)
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
        """

    var content: any View {
        Grid {
            HStack {
                DebugInfoLabel()

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
            .horizontalAlignment(.center)
            .gridRow(0)

            // The browser takes the STAR row - as tall as the window leaves -
            // and everything around it keeps its own height.
            WebView("https://example.com")
                .aim(browser)
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
                .horizontalAlignment(.center)
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

    var notes: Element? {
        VStack {
            Label("Follow the page's own link, and Back lights up: `canGoBack` and "
                + "`canGoForward` are reported into bindings after every navigation. "
                + "Back, Forward, Reload and the title question are acts aimed at the "
                + "view with `@Aim`.")
                .fontSize(12)
                .textColor(Palette.subtle)

            Label("`.onProcessTerminated` reports what no button here can provoke: the "
                + "platform runs web content in a process of its own and ends it when "
                + "memory runs short, which leaves the view blank. `reload()` brings the "
                + "page back.")
                .fontSize(12)
                .textColor(Palette.subtle)
        }
        .spacing(8)
    }
}

/// HTML written in the tree rather than fetched. Nothing here touches the
/// network.
private struct WrittenInPlacePart: ExampleContent {
    static let code = """
        struct WrittenInPlacePart: ContentView {
            var content: any View {
                WebView()
                    .source(html: "<h2>Written in place</h2><p>No network involved.</p>")
            }
        }
        """

    var content: any View {
        WebView()
            .source(html: "<h2>Written in place</h2><p>No network involved.</p>")
    }

    var notes: Element? {
        Label("`source(html:)` shows HTML written in place, without the network. Web "
            + "content scrolls itself, which is why this page holds still and the view "
            + "fills the height the window gives it.")
            .fontSize(12)
            .textColor(Palette.subtle)
    }
}
