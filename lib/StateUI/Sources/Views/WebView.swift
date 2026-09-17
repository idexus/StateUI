// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A view showing web content, and the acts aimed at it.

/// WebView's own properties - the half a `Style<WebView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol WebViewProperties: PropertyContainer {}

extension WebViewProperties {
    /// What the view calls itself to the server it asks.
    ///
    /// Left unwritten it is the platform's own browser string, which is what a
    /// site expects. Writing one is for a server that answers differently by
    /// client - an application's own name and version, say.
    public func userAgent(_ value: String) -> Modified {
        setValue(WebViewContract.userAgent, value)
    }

    /// The page it shows, by URL.
    ///
    /// The kind travels in front of the address - see `WebViewSource` -
    /// because a source is one of two things and the wire says which rather
    /// than leaving the host to tell them apart by shape.
    public func source(_ url: String) -> Modified {
        setValue(WebViewContract.source, .url(url))
    }

    /// The page it shows, written here rather than fetched.
    ///
    ///     WebView().source(html: "<h1>Offline</h1>")
    ///
    /// - Parameter html: The document itself, not a path to one.
    /// - Parameter baseUrl: What relative links in it resolve against, when
    ///   there are any.
    public func source(html: String, baseUrl: String? = nil) -> Modified {
        setValue(WebViewContract.source, .html(html, baseUrl: baseUrl))
    }
}

/// A view showing web content - a page fetched by URL, or HTML written here.
///
///     WebView("https://example.com")
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
/// has no control to call a method on. `.aim(_:)` is what puts the view in the
/// `Aim` those are called on. What the view REPORTS travels the
/// other way, into a binding: `.canGoBack($hasBack)`.
public struct WebView: View, WebViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<WebView>` is written against.
    public init() {
        node = Node(contract: WebViewContract.self)
    }

    /// A view on the page at `url`.
    public init(_ url: String) {
        node = Node(contract: WebViewContract.self)
        node.write(WebViewContract.source, .url(url))
    }

    // MARK: Properties

    // MARK: What the platform reports

    /// Whether there is a page behind this one - what enables a Back button.
    /// Read-only, and set by the platform after every navigation, so this only
    /// writes INTO the binding.
    public func canGoBack(_ binding: Binding<Bool>) -> Self {
        onEvent(WebViewContract.canGoBackChanged) { can in
            binding.wrappedValue = can
        }
    }

    /// Whether there is a page ahead of this one - true only after going back,
    /// and what enables a Forward button. Written INTO the binding by the
    /// platform, like `canGoBack`.
    public func canGoForward(_ binding: Binding<Bool>) -> Self {
        onEvent(WebViewContract.canGoForwardChanged) { can in
            binding.wrappedValue = can
        }
    }

    // MARK: Events

    /// Fires as a navigation starts, with where it is going.
    ///
    /// OBSERVING only: the platform can cancel a navigation only before its
    /// own event returns, and a handler here runs a boundary away, after it
    /// has - so there is deliberately nothing to set. A page that must not be
    /// left is a page not navigated to.
    public func onNavigating(_ handler: @escaping ValueEventHandler<WebNavigation>) -> Self {
        onEvent(WebViewContract.navigating) { event, url in
            try await handler(WebNavigation(event: event, url: url))
        }
    }

    /// Fires when a navigation finished, with how it ended - the place to
    /// clear a spinner, or to say a page could not be fetched.
    public func onNavigated(_ handler: @escaping ValueEventHandler<WebNavigated>) -> Self {
        onEvent(WebViewContract.navigated) { result, event, url in
            try await handler(WebNavigated(result: result, event: event, url: url))
        }
    }

    /// Fires when the platform's web process died under the view - out of
    /// memory, usually - leaving it blank. `reload()` is the recovery.
    public func onProcessTerminated(_ handler: @escaping EventHandler) -> Self {
        onEvent(WebViewContract.processTerminated, handler)
    }
}

// MARK: - What a navigation reports

/// Why a navigation happened.
///
/// The numbers are THIS LIBRARY's, declaration order from 0, and the host
/// translates its toolkit's reason onto the member that means the same. A
/// toolkit's own numbers stay out of it: a toolkit release free to renumber
/// its enum would otherwise have every report here read as a different
/// reason, silently.
public enum WebNavigationEvent: Int32, Sendable, HostRepresentable {
    /// No reason named - what the host answers for a reason it has no case
    /// for. Windows sends this for a view's FIRST navigation - the source it
    /// was given before its browser existed - so it is an ordinary answer
    /// there rather than a fault.
    case unknown = 0

    /// The view went back a page.
    case back = 1

    /// The view went forward again.
    case forward = 2

    /// A new page - a source assigned, or a link followed.
    case newPage = 3

    /// The same page, fetched again.
    case refresh = 4

    /// The member a number names - a closed vocabulary, so `.enumeration` and
    /// not a plain number - and `.unknown` for a member this side has no case
    /// for. Nil for anything that is not one, so a report of the wrong SHAPE
    /// still leaves the handler alone.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .enumeration(let member) = propValue else { return nil }
        self = WebNavigationEvent(rawValue: member) ?? .unknown
    }
}

/// How a navigation ended.
///
/// The numbers are THIS LIBRARY's and the host translates its toolkit's
/// outcome onto the member that means the same, exactly as
/// `WebNavigationEvent` above.
public enum WebNavigationResult: Int32, Sendable, HostRepresentable {
    /// No outcome named - and what the host answers for an outcome it has no
    /// case for. Read `.success` before treating a navigation as arrived;
    /// this is not it.
    case unknown = 0

    /// The page arrived.
    case success = 1

    /// The navigation was called off before it finished.
    case cancel = 2

    /// The server never answered.
    case timeout = 3

    /// It could not be fetched - no connection, no such host, an error page.
    case failure = 4

    /// The member a number names - a closed vocabulary, so `.enumeration` and
    /// not a plain number - and `.unknown` for a member this side has no case
    /// for. Nil for anything that is not one, so a report of the wrong SHAPE
    /// still leaves the handler alone.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .enumeration(let member) = propValue else { return nil }
        self = WebNavigationResult(rawValue: member) ?? .unknown
    }
}

/// One navigation, as it starts.
public struct WebNavigation: Equatable, Sendable {
    /// Why it happened.
    public var event: WebNavigationEvent

    /// Where it is going.
    public var url: String
}

/// One navigation, as it ends.
public struct WebNavigated: Equatable, Sendable {
    /// How it ended - `.success` is a page on screen, anything else is not.
    public var result: WebNavigationResult

    /// Why it happened.
    public var event: WebNavigationEvent

    /// Where it went.
    public var url: String
}

// MARK: - What it shows

/// What a web view shows: a page fetched from an address, or a document
/// written here.
///
///     WebView().source(html: "<h1>Offline</h1>")
///
/// The kind crosses in front of what it is made of, because a source is one
/// of two things and the wire says which rather than leaving the host to tell
/// them apart by shape: an address as the kind and the address, a document as
/// the kind, the document and its base address or nothing - three values
/// whether or not there is a base address, so the host reads the same three
/// places every time.
public enum WebViewSource: Equatable, Sendable, HostRepresentable {
    /// A page fetched from an address.
    case url(String)

    /// A document written into the description itself, and the address its
    /// relative links resolve against, where there is one.
    case html(String, baseUrl: String?)

    /// Which of the two a source is, as the number that crosses - numbered by
    /// this library, the way a `BorderShape`'s kinds are.
    private enum Kind: Int32 {
        case url = 0
        case html = 1
    }

    /// The kind, then what it is made of.
    public var propValue: PropValue {
        switch self {
        case .url(let address):
            .values([.enumeration(Kind.url.rawValue), .string(address)])
        case .html(let document, let baseUrl):
            .values([
                .enumeration(Kind.html.rawValue), .string(document),
                baseUrl.map { PropValue.string($0) } ?? .nothing,
            ])
        }
    }

    /// The source a kind and its parts name - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .values(let parts) = propValue, case .enumeration(let number)? = parts.first,
              let kind = Kind(rawValue: number)
        else { return nil }

        switch (kind, parts.count) {
        case (.url, 2):
            guard case .string(let address) = parts[1] else { return nil }
            self = .url(address)
        case (.html, 3):
            guard case .string(let document) = parts[1] else { return nil }

            switch parts[2] {
            case .string(let baseUrl): self = .html(document, baseUrl: baseUrl)
            case .nothing: self = .html(document, baseUrl: nil)
            default: return nil
            }
        default:
            return nil
        }
    }
}

// MARK: - The acts

extension Aim where Target == WebView {
    /// Goes back a page, when there is one - `.canGoBack` says whether. On a
    /// view with nothing behind it this does nothing.
    ///
    ///     @Aim(WebView.self) private var browser
    ///     @State private var hasBack = false
    ///
    ///     WebView("https://example.com")
    ///         .aim(browser)
    ///         .canGoBack($hasBack)
    ///
    ///     Button("Back")
    ///         .isEnabled(hasBack)
    ///         .onClicked { try await browser.goBack() }
    ///
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a WebView.
    public nonisolated(nonsending) func goBack() async throws {
        try await call(WebViewContract.goBack)
    }

    /// Goes forward again, after going back.
    ///
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a WebView.
    public nonisolated(nonsending) func goForward() async throws {
        try await call(WebViewContract.goForward)
    }

    /// Fetches the current page again - and puts a view back on its feet after
    /// `onProcessTerminated`.
    ///
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a WebView.
    public nonisolated(nonsending) func reload() async throws {
        try await call(WebViewContract.reload)
    }

    /// Runs JavaScript in the page and answers what it evaluated to, as text.
    ///
    ///     let title = try await browser.evaluateJavaScript("document.title")
    ///
    /// - Returns: What the script's last expression evaluated to, written as
    ///   text by the platform - a number arrives as `"42"`, an object as its
    ///   JSON. Empty when the page answered nothing.
    /// - Throws: `StateUIError` when no view of that id is being shown, or
    ///   the view it names is not a WebView.
    public nonisolated(nonsending) func evaluateJavaScript(_ script: String) async throws -> String {
        let answer: String? = try await call(WebViewContract.evaluateJavaScript, script)
        return answer ?? ""
    }
}
