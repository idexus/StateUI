// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `WebView`'s own properties, shared by the control and its `Style<WebView>`.
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
}

/// A view showing web content - a page fetched from its address, or HTML written here.
///
///     WebView("https://example.com")
///
///     WebView()
///         .source(html: "<h1>Hello</h1>")
///
/// The web content scrolls itself, so give it room of its own - a Grid row, or
/// a page without a scroller - rather than a place inside a ScrollView.
///
/// What the view is told to do is an act called through its aim -
/// `browser.goBack()`, `browser.reload()`,
/// `browser.evaluateJavaScript("…")`; what it reports arrives in a binding,
/// `.canGoBack(into: $hasBack)`.
public struct WebView: ElementView, WebViewProperties, FocusElement {
    /// The node this control describes.
    public var node: Node

    /// A web view with no page, which a host's driver and the conformance cases make to prove what no source does.
    @_spi(Host) public init() {
        node = Node(contract: WebViewContract.self)
    }

    /// A view on the page at `address`.
    public init(_ address: String) {
        self.init()
        self = setValue(WebViewContract.source, .address(address))
    }

    /// A view on a document of its own.
    public init(html: String) {
        self = WebView().source(html: html)
    }

    /// A view on a document of its own, its relative addresses read against `baseAddress`.
    public init(html: String, baseAddress: String?) {
        self = WebView().source(html: html, baseAddress: baseAddress)
    }

    /// The page at an address.
    func source(_ address: String) -> Modified {
        setValue(WebViewContract.source, .address(address))
    }

    /// A document of its own.
    func source(html: String, baseAddress: String? = nil) -> Modified {
        setValue(WebViewContract.source, .html(html, baseAddress: baseAddress))
    }

    // MARK: What the platform reports

    /// Whether there is a page behind this one - what enables a Back button -
    /// written into the binding by the platform after every navigation.
    public func canGoBack(into state: Binding<Bool>) -> Modified {
        onEvent(WebViewContract.canGoBackChanged) { can in
            state.wrappedValue = can
        }
    }

    /// Whether there is a page ahead of this one - true only after going back,
    /// and what enables a Forward button - written into the binding.
    public func canGoForward(into state: Binding<Bool>) -> Modified {
        onEvent(WebViewContract.canGoForwardChanged) { can in
            state.wrappedValue = can
        }
    }

    // MARK: Events

    /// Fires as a navigation starts, with where it is going. Observing only: it
    /// cannot cancel the navigation.
    public func onNavigating(_ handler: @escaping @MainActor (WebNavigation) throws -> Void) -> Modified {
        onEvent(WebViewContract.navigating) { kind, address in try handler(WebNavigation(kind: kind, address: address)) }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onNavigating(policy: GatePolicy, _ handler: @escaping ValueEventHandler<WebNavigation>) -> Modified {
        onEvent(WebViewContract.navigating, policy: policy) { kind, address in
            try await handler(WebNavigation(kind: kind, address: address))
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onNavigating(gate: Gate, _ handler: @escaping ValueEventHandler<WebNavigation>) -> Modified {
        onEvent(WebViewContract.navigating, gate: gate) { kind, address in
            try await handler(WebNavigation(kind: kind, address: address))
        }
    }

    /// Fires when a navigation finished, with how it ended - the place to
    /// clear a spinner, or to say a page could not be fetched.
    public func onNavigated(_ handler: @escaping @MainActor (WebNavigated) throws -> Void) -> Modified {
        onEvent(WebViewContract.navigated) { result, kind, address in
            try handler(WebNavigated(result: result, kind: kind, address: address))
        }
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onNavigated(policy: GatePolicy, _ handler: @escaping ValueEventHandler<WebNavigated>) -> Modified {
        onEvent(WebViewContract.navigated, policy: policy) { result, kind, address in
            try await handler(WebNavigated(result: result, kind: kind, address: address))
        }
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onNavigated(gate: Gate, _ handler: @escaping ValueEventHandler<WebNavigated>) -> Modified {
        onEvent(WebViewContract.navigated, gate: gate) { result, kind, address in
            try await handler(WebNavigated(result: result, kind: kind, address: address))
        }
    }

    /// Fires when the platform's web process died under the view - out of
    /// memory, usually - leaving it blank. `reload()` is the recovery.
    public func onProcessTerminated(_ handler: @escaping @MainActor () throws -> Void) -> Modified {
        onEvent(WebViewContract.processTerminated, handler)
    }

    /// The same, with a handler that awaits: its `policy` says what the event does when it comes
    /// again while a run is under way.
    public func onProcessTerminated(policy: GatePolicy, _ handler: @escaping EventHandler) -> Modified {
        onEvent(WebViewContract.processTerminated, policy: policy, handler)
    }

    /// The same, through `gate`, which every handler and task written with it shares.
    public func onProcessTerminated(gate: Gate, _ handler: @escaping EventHandler) -> Modified {
        onEvent(WebViewContract.processTerminated, gate: gate, handler)
    }
}

// MARK: - What a navigation reports

/// Why a navigation happened.
public enum WebNavigationKind: Int32, Sendable, HostRepresentable {
    /// No reason named - what the host answers for a reason it has no case
    /// for. Windows sends it for a view's first navigation, so it is an
    /// ordinary answer there rather than a fault.
    case unknown = 0

    /// The view went back a page.
    case back = 1

    /// The view went forward again.
    case forward = 2

    /// A new page - a source assigned, or a link followed.
    case newPage = 3

    /// The same page, fetched again.
    case reload = 4

    /// The member a number names, `.unknown` for one this side has no case for,
    /// and nil for anything that is not a member.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .enumeration(let member) = propValue else { return nil }
        self = WebNavigationKind(rawValue: member) ?? .unknown
    }
}

/// How a navigation ended.
public enum WebNavigationResult: Int32, Sendable, HostRepresentable {
    /// No outcome named - what the host answers for an outcome it has no case
    /// for. Only `.success` means the page arrived.
    case unknown = 0

    /// The page arrived.
    case success = 1

    /// The navigation was called off before it finished.
    case cancelled = 2

    /// The server never answered.
    case timeout = 3

    /// It could not be fetched - no connection, no such host, an error page.
    case failure = 4

    /// The member a number names, `.unknown` for one this side has no case for,
    /// and nil for anything that is not a member.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard case .enumeration(let member) = propValue else { return nil }
        self = WebNavigationResult(rawValue: member) ?? .unknown
    }
}

/// One navigation, as it starts.
public struct WebNavigation: Equatable, Sendable {
    /// Why it happened.
    public var kind: WebNavigationKind

    /// Where it is going.
    public var address: String
}

/// One navigation, as it ends.
public struct WebNavigated: Equatable, Sendable {
    /// How it ended - `.success` is a page on screen, anything else is not.
    public var result: WebNavigationResult

    /// Why it happened.
    public var kind: WebNavigationKind

    /// Where it went.
    public var address: String
}

// MARK: - What it shows

// Design: docs/design/views/controls.md#web-view
/// What a web view shows: a page fetched from an address, or a document
/// written here.
///
///     WebView().source(html: "<h1>Offline</h1>")
public enum WebViewSource: Equatable, Sendable, HostRepresentable {
    /// A page fetched from an address.
    case address(String)

    /// A document written into the description itself, and the address its
    /// relative links resolve against, where there is one.
    case html(String, baseAddress: String?)

    /// Which of the two a source is, as the number that crosses.
    private enum Kind: Int32 {
        case address = 0
        case html = 1
    }

    /// The kind, then what it is made of.
    public var propValue: PropValue {
        switch self {
        case .address(let address):
            .values([.enumeration(Kind.address.rawValue), .string(address)])
        case .html(let document, let baseAddress):
            .values([
                .enumeration(Kind.html.rawValue), .string(document),
                baseAddress.map { PropValue.string($0) } ?? .nothing,
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
        case (.address, 2):
            guard case .string(let address) = parts[1] else { return nil }
            self = .address(address)
        case (.html, 3):
            guard case .string(let document) = parts[1] else { return nil }

            switch parts[2] {
            case .string(let base): self = .html(document, baseAddress: base)
            case .nothing: self = .html(document, baseAddress: nil)
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
    ///         .canGoBack(into: $hasBack)
    ///
    ///     Button("Back")
    ///         .isEnabled(hasBack)
    ///         .onClicked(policy: .ignoreWhileRunning) { try await browser.goBack() }
    ///
    /// - Throws: `StateUIError` when the aim is on no view or on two, or its
    ///   view is no longer shown.
    public func goBack() async throws {
        try await call(WebViewContract.goBack)
    }

    /// Goes forward again, after going back.
    ///
    /// - Throws: `StateUIError` when the aim is on no view or on two, or its
    ///   view is no longer shown.
    public func goForward() async throws {
        try await call(WebViewContract.goForward)
    }

    /// Fetches the current page again - and puts a view back on its feet after
    /// `onProcessTerminated`.
    ///
    /// - Throws: `StateUIError` when the aim is on no view or on two, or its
    ///   view is no longer shown.
    public func reload() async throws {
        try await call(WebViewContract.reload)
    }

    /// Runs JavaScript in the page and answers what it evaluated to, as text.
    ///
    ///     let title = try await browser.evaluateJavaScript("document.title")
    ///
    /// - Returns: What the script's last expression evaluated to, written as
    ///   text by the platform - a number arrives as `"42"`, an object as its
    ///   JSON. Empty when the page answered nothing.
    /// - Throws: `StateUIError` when the aim is on no view or on two, or its
    ///   view is no longer shown.
    public func evaluateJavaScript(_ script: String) async throws -> String {
        let answer: String? = try await call(WebViewContract.evaluateJavaScript, script)
        return answer ?? ""
    }
}
