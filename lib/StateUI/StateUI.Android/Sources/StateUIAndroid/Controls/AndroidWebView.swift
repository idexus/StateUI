// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A WebView: Android's own web view, in the host's `StateUIWebView`, which makes it again should its web
/// process die. What the page does comes back as the element's events, by the host layer's web rules: why a
/// navigation began (`WebNavigationCause`), a way back or forward only as it changes (`WebHistory`).
/// Design: docs/design/platforms/android/controls.md#a-web-view
@MainActor
final class AndroidWebView: AndroidView {
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
    private var cause = WebNavigationCause()

    /// The way back and forward as last said.
    private var history = WebHistory()

    /// The page's own touches and hovering are seen by its element's gestures before the page gets them.
    override func watchTouches() {
        Java.call(reference, JavaAPI.watchWeb, .object(listener.reference))
    }

    init() {
        super.init { number in
            Java.new(JavaAPI.webView, JavaAPI.newWebView, .object(AndroidRenderer.context), .long(number))
        }
    }

    /// Shows the page at an address, or a document written in place, asking as `agent`; none leaves the view
    /// as it is. The page and its agent cross together, the agent first. A document with no address of its own
    /// is gone to as a `data:` address (`WebDocument`).
    /// Design: docs/design/platforms/android/controls.md#a-web-view
    func show(_ source: WebViewSource?, userAgent agent: String?) {
        Java.frame {
            let agent = agent.flatMap(Java.string)
            switch source {
            case .url(let address)?:
                Java.call(reference, JavaAPI.loadWeb, .object(agent), .object(Java.string(address)))
            case .html(let document, nil)?:
                Java.call(
                    reference, JavaAPI.loadWeb, .object(agent), .object(Java.string(WebDocument.address(of: document))))
            case .html(let document, let base?)?:
                Java.call(
                    reference, JavaAPI.showWeb, .object(agent), .object(Java.string(document)),
                    .object(Java.string(base)))
            case nil:
                Java.call(reference, JavaAPI.setWebUserAgent, .object(agent))
            }
        }
    }

    /// What the view calls itself to a server from the next page on; none for the platform's own.
    func setUserAgent(_ agent: String?) {
        Java.frame { Java.call(reference, JavaAPI.setWebUserAgent, .object(agent.flatMap(Java.string))) }
    }

    /// Steps back, forward, or loads the page again - the navigation's cause the program's. Android tells a
    /// navigation after the call returns.
    func goBack() {
        if Java.callBool(reference, JavaAPI.webGoBack) { cause.ask(.back) }
    }

    func goForward() {
        if Java.callBool(reference, JavaAPI.webGoForward) { cause.ask(.forward) }
    }

    func reload() {
        cause.ask(.refresh)
        Java.call(reference, JavaAPI.webReload)
    }

    /// Runs `script` in the page; what it evaluated to answers the act waiting under `ticket`.
    func evaluate(_ script: String, ticket: Int64) {
        Java.frame { Java.call(reference, JavaAPI.webEvaluate, .object(Java.string(script)), .long(ticket)) }
    }

    /// A navigation began: Android tells no reason, so one the program did not ask for is a new page.
    func navigating(to address: String) {
        onNavigating?(cause.begin(told: .newPage), address)
    }

    func navigated(result: Int32, to address: String) {
        onNavigated?(WebNavigationResult(rawValue: result) ?? .unknown, cause.current, address)
    }

    /// The history as it stands: a way that changed is said - the way back before the way forward.
    func history(back: Bool, forward: Bool) {
        let changed = history.changes(back: back, forward: forward)
        if let back = changed.back { onCanGoBack?(back) }
        if let forward = changed.forward { onCanGoForward?(forward) }
    }

    /// The element left: the web view lets go of its page and its web process.
    override func detach() {
        super.detach()
        onNavigating = nil
        onNavigated = nil
        onCanGoBack = nil
        onCanGoForward = nil
        onProcessGone = nil
        Java.call(reference, JavaAPI.releaseWeb)
    }
}
