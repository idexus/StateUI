// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: WebView.

/// WebView's own properties - the half a `Style<WebView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol WebViewProperties: PropertyContainer {}

extension WebViewProperties {
    /// What the view calls itself to the server it asks.
    /// MAUI: WebView.UserAgent.
    ///
    /// Left unwritten it is the platform's own browser string, which is what a
    /// site expects. Writing one is for a server that answers differently by
    /// client - an application's own name and version, say.
    public func userAgent(_ value: String) -> Modified {
        setValue(.userAgent, .string(value))
    }

    /// The page it shows, by URL. MAUI: WebView.Source, which the host makes a
    /// UrlWebViewSource of.
    ///
    /// The kind travels in front of the address - see `WebView.SourceKind` -
    /// because a source is one of two things and the wire says which rather
    /// than leaving the host to tell them apart by shape.
    public func source(_ url: String) -> Modified {
        setValue(.source, .values([WebView.SourceKind.url.propValue, .string(url)]))
    }

    /// The page it shows, written here rather than fetched. MAUI:
    /// WebView.Source, as an HtmlWebViewSource.
    ///
    ///     WebView().source(html: "<h1>Offline</h1>")
    ///
    /// - Parameter html: The document itself, not a path to one.
    /// - Parameter baseUrl: What relative links in it resolve against, when
    ///   there are any. MAUI: HtmlWebViewSource.BaseUrl.
    public func source(html: String, baseUrl: String? = nil) -> Modified {
        // Three values whether or not there is a base url, the third being
        // `.nothing` when there is none: the COUNT says nothing about the
        // value, so the host reads the same three places every time.
        setValue(.source, .values([
            WebView.SourceKind.html.propValue,
            .string(html),
            baseUrl.map { PropValue.string($0) } ?? .nothing,
        ]))
    }
}

/// A view showing web content - a page fetched by URL, or HTML written here.
/// MAUI: WebView.
///
///     WebView("https://dotnet.microsoft.com")
///
///     WebView()
///         .source(html: "<h1>Hello</h1>")
///
/// The web content scrolls ITSELF, so a WebView wants room of its own - a Grid
/// row, or a page without a scroller - rather than a place inside a ScrollView,
/// where the two scrollers fight over every drag. Same rule as any gesture.
///
/// Everything the view is TOLD to do is an ACT aimed at it - `browser.goBack()`,
/// `browser.reload()`, `browser.evaluateJavaScript("…")` - because a description
/// has no control to call a method on. `.assign(_:)` is what puts the view into
/// the `ControlState` those are called on. What the view REPORTS travels the
/// other way, into a binding: `.canGoBack($hasBack)`.
public struct WebView: View, WebViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<WebView>` is written against.
    public init() {
        node = Node(type: .webView)
    }

    /// A view on the page at `url`.
    public init(_ url: String) {
        node = Node(type: .webView, props: [
            .source: .values([SourceKind.url.propValue, .string(url)]),
        ])
    }

    /// Which of the two things a source is, as the number that crosses.
    ///
    /// MAUI has a CLASS per kind - UrlWebViewSource, HtmlWebViewSource -
    /// rather than an enum, so there is no MAUI member to name: these are
    /// numbered by this library and mirrored by `SwiftWebViewSourceKind`, the
    /// way a `StrokeShape`'s kinds are.
    enum SourceKind: Int32, Sendable {
        /// A page fetched from an address. MAUI: UrlWebViewSource.
        case url = 0

        /// A document written into the description itself.
        /// MAUI: HtmlWebViewSource.
        case html = 1

        var propValue: PropValue { .enumeration(rawValue) }
    }

    // MARK: Properties

    // MARK: What the platform reports

    /// Whether there is a page behind this one - what enables a Back button.
    /// MAUI: WebView.CanGoBack, which is read-only and set by the platform
    /// after every navigation, so this only writes INTO the binding.
    public func canGoBack(_ binding: Binding<Bool>) -> Self {
        addHandler(.canGoBackChanged) {
            if let can = EventBuffer.current.value()?.bool {
                binding.wrappedValue = can
            }
        }
    }

    /// Whether there is a page ahead of this one - true only after going back,
    /// and what enables a Forward button. Written INTO the binding by the
    /// platform, like `canGoBack`. MAUI: WebView.CanGoForward.
    public func canGoForward(_ binding: Binding<Bool>) -> Self {
        addHandler(.canGoForwardChanged) {
            if let can = EventBuffer.current.value()?.bool {
                binding.wrappedValue = can
            }
        }
    }

    // MARK: Events

    /// Fires as a navigation starts, with where it is going. MAUI:
    /// WebView.Navigating.
    ///
    /// OBSERVING only: MAUI's event can cancel the navigation by setting
    /// `Cancel` before the event returns, and a handler here runs a boundary
    /// away, after it has - so there is deliberately nothing to set. A page
    /// that must not be left is a page not navigated to.
    public func onNavigating(_ handler: @escaping ValueEventHandler<WebNavigation>) -> Self {
        addHandler(.navigating) {
            guard let report = WebNavigation(EventBuffer.current) else { return }
            try await handler(report)
        }
    }

    /// Fires when a navigation finished, with how it ended - the place to
    /// clear a spinner, or to say a page could not be fetched. MAUI:
    /// WebView.Navigated.
    public func onNavigated(_ handler: @escaping ValueEventHandler<WebNavigated>) -> Self {
        addHandler(.navigated) {
            guard let report = WebNavigated(EventBuffer.current) else { return }
            try await handler(report)
        }
    }

    /// Fires when the platform's web process died under the view - out of
    /// memory, usually - leaving it blank. `reload()` is the recovery. MAUI:
    /// WebView.ProcessTerminated.
    public func onProcessTerminated(_ handler: @escaping EventHandler) -> Self {
        addHandler(.processTerminated, handler)
    }
}

// MARK: - What a navigation reports

/// Why a navigation happened. MAUI: WebNavigationEvent.
///
/// The numbers are THIS LIBRARY's, declaration order from 0, and the host
/// translates each onto the MAUI member named below it, out of the
/// `SwiftWebNavigationEvent` mirror. MAUI's own numbers stay out of it: a
/// release free to renumber its enum is a release that would have every report
/// here read as a different reason, silently.
public enum WebNavigationEvent: Int32, Sendable {
    /// MAUI named no reason - what the host answers for a member it has no
    /// case for. Windows sends this for a view's FIRST navigation - the source
    /// it was given before its browser existed - so it is an ordinary answer
    /// there rather than a fault.
    case unknown = 0

    /// The view went back a page. MAUI: WebNavigationEvent.Back.
    case back = 1

    /// The view went forward again. MAUI: WebNavigationEvent.Forward.
    case forward = 2

    /// A new page - a source assigned, or a link followed. MAUI:
    /// WebNavigationEvent.NewPage.
    case newPage = 3

    /// The same page, fetched again. MAUI: WebNavigationEvent.Refresh.
    case refresh = 4

    /// Reads a payload's value - a member of a closed vocabulary, so
    /// `.enumeration` and not a plain number. Nil for anything that is not
    /// one, so a report of the wrong SHAPE still leaves the handler alone,
    /// while a member this side has no case for reads as `.unknown`.
    init?(_ value: PropValue?) {
        guard let member = value?.enumeration else { return nil }
        self = WebNavigationEvent(rawValue: member) ?? .unknown
    }
}

/// How a navigation ended. MAUI: WebNavigationResult.
///
/// The numbers are THIS LIBRARY's and the host translates them by name,
/// exactly as `WebNavigationEvent` above.
public enum WebNavigationResult: Int32, Sendable {
    /// MAUI named no outcome - and what the host answers for a member it has
    /// no case for. Read `.success` before treating a navigation as arrived;
    /// this is not it.
    case unknown = 0

    /// The page arrived. MAUI: WebNavigationResult.Success.
    case success = 1

    /// The navigation was called off before it finished. MAUI:
    /// WebNavigationResult.Cancel.
    case cancel = 2

    /// The server never answered. MAUI: WebNavigationResult.Timeout.
    case timeout = 3

    /// It could not be fetched - no connection, no such host, an error page.
    /// MAUI: WebNavigationResult.Failure.
    case failure = 4

    /// Reads a payload's value - a member of a closed vocabulary, so
    /// `.enumeration` and not a plain number. Nil for anything that is not
    /// one, so a report of the wrong SHAPE still leaves the handler alone,
    /// while a member this side has no case for reads as `.unknown`.
    init?(_ value: PropValue?) {
        guard let member = value?.enumeration else { return nil }
        self = WebNavigationResult(rawValue: member) ?? .unknown
    }
}

/// One navigation, as it starts. MAUI: WebNavigatingEventArgs.
public struct WebNavigation: Equatable, Sendable {
    /// Why it happened. MAUI: WebNavigationEventArgs.NavigationEvent.
    public var event: WebNavigationEvent

    /// Where it is going. MAUI: WebNavigationEventArgs.Url.
    public var url: String

    /// Reads a payload's two values - why, then where, the order MAUI
    /// declares them. A string carries its length on this wire, so a url
    /// with commas in it needs no rule about travelling last.
    init?(_ payload: [PropValue]) {
        guard let event = WebNavigationEvent(payload.value(0)),
              let url = payload.value(1)?.string else { return nil }

        self.event = event
        self.url = url
    }
}

/// One navigation, as it ends. MAUI: WebNavigatedEventArgs.
public struct WebNavigated: Equatable, Sendable {
    /// How it ended - `.success` is a page on screen, anything else is not.
    /// MAUI: WebNavigatedEventArgs.Result.
    public var result: WebNavigationResult

    /// Why it happened. MAUI: WebNavigationEventArgs.NavigationEvent.
    public var event: WebNavigationEvent

    /// Where it went. MAUI: WebNavigationEventArgs.Url.
    public var url: String

    /// Reads a payload's three values - how it ended, why, then where, the
    /// order MAUI declares them.
    init?(_ payload: [PropValue]) {
        guard let result = WebNavigationResult(payload.value(0)),
              let event = WebNavigationEvent(payload.value(1)),
              let url = payload.value(2)?.string else { return nil }

        self.result = result
        self.event = event
        self.url = url
    }
}

// MARK: - The acts

extension ControlState where Target == WebView {
    /// Goes back a page, when there is one - `.canGoBack` says whether. On a
    /// view with nothing behind it this does nothing, exactly as in MAUI.
    /// MAUI: WebView.GoBack.
    ///
    ///     @State private var browser = ControlState<WebView>()
    ///     @State private var hasBack = false
    ///
    ///     WebView("https://dotnet.microsoft.com")
    ///         .assign(browser)
    ///         .canGoBack($hasBack)
    ///
    ///     Button("Back")
    ///         .isEnabled(hasBack)
    ///         .onClicked { try await browser.goBack() }
    ///
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a WebView.
    public nonisolated(nonsending) func goBack() async throws {
        try await stateUICall(.goBack, [try target])
    }

    /// Goes forward again, after going back. MAUI: WebView.GoForward.
    ///
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a WebView.
    public nonisolated(nonsending) func goForward() async throws {
        try await stateUICall(.goForward, [try target])
    }

    /// Fetches the current page again - and puts a view back on its feet after
    /// `onProcessTerminated`. MAUI: WebView.Reload.
    ///
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a WebView.
    public nonisolated(nonsending) func reload() async throws {
        try await stateUICall(.reload, [try target])
    }

    /// Runs JavaScript in the page and answers what it evaluated to, as text.
    /// MAUI: WebView.EvaluateJavaScriptAsync, the `Async` dropped because
    /// `await` at the call site already says it.
    ///
    ///     let title = try await browser.evaluateJavaScript("document.title")
    ///
    /// - Returns: What the script's last expression evaluated to, written as
    ///   text by the platform - a number arrives as `"42"`, an object as its
    ///   JSON. Empty when the page answered nothing.
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a WebView.
    public nonisolated(nonsending) func evaluateJavaScript(_ script: String) async throws -> String {
        try await stateUICall(.evaluateJavaScriptAsync, [try target, .string(script)])
            .value()?.string ?? ""
    }
}
