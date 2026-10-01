// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import WebKit
import StateUIWebView
@_spi(Host) import StateUIWebViewHost

/// A WebView on UIKit: WebKit's own web view. What the page does comes back as the element's events - a navigation as
/// it starts and ends, with why; a history flag only when it changes; the web process dying.
/// Design: docs/design/platforms/uikit/controls.md#a-web-view
@MainActor
final class UIKitWebView: WKWebView, WKNavigationDelegate {
    /// What the view does when a navigation starts: why, and where it goes.
    var onNavigating: ((WebNavigationEvent, String) -> Void)?

    /// What the view does when a navigation ends: how, why, and where it went.
    var onNavigated: ((WebNavigationResult, WebNavigationEvent, String) -> Void)?

    /// What the view does when there comes to be, or stops being, a page behind it and ahead of it.
    var onCanGoBack: ((Bool) -> Void)?
    var onCanGoForward: ((Bool) -> Void)?

    /// What the view does when its web process died, leaving it blank.
    var onProcessGone: (() -> Void)?

    /// Why the navigation under way began, and why the next begins where the program said so.
    private var cause = WebNavigationEvent.unknown
    private var asked: WebNavigationEvent?

    /// The page last asked for by its address.
    private var shown: URLRequest?

    /// A page asked for and not loaded yet: loaded once the element's values are all applied.
    private var pending: WebViewSource?

    /// The history as last said: whether there was a page behind and ahead.
    private var said = (back: false, forward: false)

    init() {
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        navigationDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitWebView is made in code")
    }

    /// What the view calls itself to the servers it asks; nil for WebKit's own.
    var agent: String? {
        get { customUserAgent }
        set { customUserAgent = newValue }
    }

    /// Shows the page at an address, or a document written in place - once the element's other values, its agent
    /// among them, are applied; no source leaves the page as it is. A document with no address of its own is gone
    /// to at its `data:` address (`WebDocument`).
    func show(_ source: WebViewSource?) {
        guard let source else { return }
        if pending == nil { Task { @MainActor [weak self] in self?.loadPending() } }
        pending = source
    }

    /// Loads the page asked for last.
    private func loadPending() {
        guard let source = pending else { return }
        pending = nil
        switch source {
        case .url(let address):
            guard let url = URL(string: address) else { return }
            shown = URLRequest(url: url)
            load(URLRequest(url: url))
        case .html(let document, let base?):
            loadHTMLString(document, baseURL: URL(string: base))
        case .html(let document, nil):
            guard let url = URL(string: WebDocument.address(of: document)) else { return }
            shown = URLRequest(url: url)
            load(URLRequest(url: url))
        }
    }

    /// Steps back or forward in the page's history, or loads the page again - the navigation's cause said as the
    /// program's.
    func step(_ event: WebNavigationEvent) {
        asked = event
        switch event {
        case .back: _ = goBack()
        case .forward: _ = goForward()
        default:
            // A page still coming WebKit reloads without asking: it is asked for again instead, and heard.
            if isLoading, let shown {
                stopLoading()
                load(shown)
            } else if reload() == nil, let shown {
                load(shown)
            }
        }
    }

    /// Runs `script` in the page; `answered` hears what it evaluated to, as text - nothing for no value.
    func evaluate(_ script: String, answered: @escaping (String?) -> Void) {
        evaluateJavaScript(script) { value, _ in
            MainActor.assumeIsolated { answered(Self.text(value)) }
        }
    }

    /// A script's value as text: words as they are, a number as it is written, anything else as JSON.
    static func text(_ value: Any?) -> String? {
        switch value {
        case nil, is NSNull: nil
        case let words as String: words
        case let number as NSNumber: number.stringValue
        case let other?:
            (try? JSONSerialization.data(withJSONObject: other)).flatMap { String(data: $0, encoding: .utf8) }
        }
    }

    // MARK: - What the page does

    func webView(
        _ web: WKWebView, decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        if action.targetFrame?.isMainFrame != false {
            defer { asked = nil }
            let told: WebNavigationEvent = switch action.navigationType {
            case .backForward: backForward(to: action.request.url)
            case .reload: .refresh
            case .linkActivated, .formSubmitted, .formResubmitted, .other: .newPage
            @unknown default: .unknown
            }
            cause = asked ?? told
            onNavigating?(cause, action.request.url?.absoluteString ?? "")
        }
        decisionHandler(.allow)
    }

    /// Whether a step through the history goes back or forward, by where it lands.
    private func backForward(to address: URL?) -> WebNavigationEvent {
        backForwardList.backList.contains { $0.url == address } ? .back : .forward
    }

    func webView(_ web: WKWebView, didCommit navigation: WKNavigation?) {
        sayHistory()
    }

    func webView(_ web: WKWebView, didFinish navigation: WKNavigation?) {
        sayHistory()
        onNavigated?(.success, cause, url?.absoluteString ?? "")
    }

    /// The history as it stands: a flag that changed is said - the way back before the way forward.
    private func sayHistory() {
        if canGoBack != said.back {
            said.back = canGoBack
            onCanGoBack?(canGoBack)
        }
        if canGoForward != said.forward {
            said.forward = canGoForward
            onCanGoForward?(canGoForward)
        }
    }

    func webView(_ web: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
        onNavigated?(Self.result(error), cause, url?.absoluteString ?? "")
    }

    func webView(_ web: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: any Error) {
        onNavigated?(Self.result(error), cause, url?.absoluteString ?? "")
    }

    func webViewWebContentProcessDidTerminate(_ web: WKWebView) {
        onProcessGone?()
    }

    /// How a navigation that failed ended: cancelled, timed out, or failed.
    private static func result(_ error: any Error) -> WebNavigationResult {
        switch (error as NSError).code {
        case NSURLErrorCancelled: .cancel
        case NSURLErrorTimedOut: .timeout
        default: .failure
        }
    }
}
#endif
