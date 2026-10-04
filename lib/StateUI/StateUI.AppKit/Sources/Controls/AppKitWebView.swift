// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import WebKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A WebView: WebKit's own web view. What the page does comes back as the element's events - a navigation as it
/// starts and ends, with why; a history flag only when it changes; the web process dying.
/// Design: docs/design/platforms/appkit/views.md#a-web-view
@MainActor
final class AppKitWebView: WKWebView, WKNavigationDelegate {
    /// What the view does when a navigation starts: why, and where it goes.
    var onNavigating: ((StateUI.WebNavigationType, String) -> Void)?

    /// What the view does when a navigation ends: how, why, and where it went.
    var onNavigated: ((WebNavigationResult, StateUI.WebNavigationType, String) -> Void)?

    /// What the view does when there comes to be, or stops being, a page behind it and ahead of it.
    var onCanGoBack: ((Bool) -> Void)?
    var onCanGoForward: ((Bool) -> Void)?

    /// What the view does when its web process died, leaving it blank.
    var onProcessGone: (() -> Void)?

    /// Why the navigation under way began, and why the next begins where the program said so.
    private var cause = WebNavigationCause()

    /// The page last asked for by its address.
    private var shown: URLRequest?

    /// The way back and forward as last said.
    private var history = StateUIHost.WebHistory()

    init() {
        super.init(frame: .zero, configuration: WKWebViewConfiguration())
        navigationDelegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitWebView is made in code")
    }

    /// Shows the page at an address, or a document written in place, asking as `agent` - the platform's own where
    /// none; no source leaves the page as it is. A document with no address of its own is gone to as a `data:`
    /// address (`WebDocument`).
    func show(_ source: WebViewSource?, userAgent agent: String?) {
        customUserAgent = agent
        switch source {
        case .url(let address)?:
            guard let url = URL(string: address) else { return }
            shown = URLRequest(url: url)
            load(URLRequest(url: url))
        case .html(let document, let base?)?:
            loadHTMLString(document, baseURL: URL(string: base))
        case .html(let document, nil)?:
            guard let url = URL(string: WebDocument.address(of: document)) else { return }
            shown = URLRequest(url: url)
            load(URLRequest(url: url))
        case nil:
            break
        }
    }

    /// Steps back or forward in the page's history, or loads the page again - the navigation's cause said as the
    /// program's.
    func step(_ event: StateUI.WebNavigationType) {
        cause.ask(event)
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

    /// Runs `script` in the page; `answered` hears what it evaluated to, as text (`ScriptAnswer`) - nothing for no
    /// value.
    func evaluate(_ script: String, answered: @escaping (String?) -> Void) {
        evaluateJavaScript(script) { value, _ in
            MainActor.assumeIsolated { answered(ScriptAnswer.text(json: Self.json(value))) }
        }
    }

    /// The value WebKit hands back, written as JSON; nil for none.
    static func json(_ value: Any?) -> String? {
        guard let value, !(value is NSNull) else { return nil }
        return (try? JSONSerialization.data(withJSONObject: value, options: .fragmentsAllowed))
            .flatMap { String(data: $0, encoding: .utf8) }
    }

    // MARK: - What the page does

    func webView(
        _ web: WKWebView, decidePolicyFor action: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        if action.targetFrame?.isMainFrame != false {
            let told: StateUI.WebNavigationType = switch action.navigationType {
            case .backForward: backForward(to: action.request.url)
            case .reload: .reload
            case .linkActivated, .formSubmitted, .formResubmitted, .other: .newPage
            @unknown default: .unknown
            }
            onNavigating?(cause.begin(told: told), action.request.url?.absoluteString ?? "")
        }
        decisionHandler(.allow)
    }

    /// Whether a step through the history goes back or forward, by where it lands.
    private func backForward(to address: URL?) -> StateUI.WebNavigationType {
        backForwardList.backList.contains { $0.url == address } ? .back : .forward
    }

    func webView(_ web: WKWebView, didCommit navigation: WKNavigation?) {
        sayHistory()
    }

    func webView(_ web: WKWebView, didFinish navigation: WKNavigation?) {
        sayHistory()
        onNavigated?(.success, cause.current, url?.absoluteString ?? "")
    }

    /// The history as it stands: a way that changed is said - the way back before the way forward.
    private func sayHistory() {
        let changed = history.changes(back: canGoBack, forward: canGoForward)
        if let back = changed.back { onCanGoBack?(back) }
        if let forward = changed.forward { onCanGoForward?(forward) }
    }

    func webView(_ web: WKWebView, didFail navigation: WKNavigation?, withError error: any Error) {
        onNavigated?(Self.result(error), cause.current, url?.absoluteString ?? "")
    }

    func webView(_ web: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: any Error) {
        onNavigated?(Self.result(error), cause.current, url?.absoluteString ?? "")
    }

    func webViewWebContentProcessDidTerminate(_ web: WKWebView) {
        onProcessGone?()
    }

    /// How a navigation that failed ended: cancelled, timed out, or failed.
    private static func result(_ error: any Error) -> WebNavigationResult {
        switch (error as NSError).code {
        case NSURLErrorCancelled: .cancelled
        case NSURLErrorTimedOut: .timeout
        default: .failure
        }
    }
}
#endif
