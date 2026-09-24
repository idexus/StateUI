// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI

/// A WebView: Android's own web view, in the host's `StateUIWebView`, which makes it again should its web
/// process die. What the page does comes back as the element's events; a history flag only when it changes.
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

    private var canGoBack = false
    private var canGoForward = false

    init() {
        super.init { number in
            Java.new(JavaAPI.webView, JavaAPI.newWebView, .object(AndroidRenderer.context), .long(number))
        }
    }

    /// Shows the page at an address, or a document written in place, asking as `agent`; none leaves the view
    /// as it is. The page and its agent cross together, the agent first.
    /// Design: docs/design/platforms/android/controls.md#a-web-view
    func show(_ source: WebViewSource?, userAgent agent: String?) {
        Java.frame {
            let agent = agent.flatMap(Java.string)
            switch source {
            case .url(let address)?:
                Java.call(reference, JavaAPI.loadWeb, .object(agent), .object(Java.string(address)))
            case .html(let document, let base)?:
                Java.call(
                    reference, JavaAPI.showWeb, .object(agent), .object(Java.string(document)),
                    .object(base.flatMap(Java.string)))
            case nil:
                Java.call(reference, JavaAPI.setWebUserAgent, .object(agent))
            }
        }
    }

    /// What the view calls itself to a server from the next page on; none for the platform's own.
    func setUserAgent(_ agent: String?) {
        Java.frame { Java.call(reference, JavaAPI.setWebUserAgent, .object(agent.flatMap(Java.string))) }
    }

    func goBack() { Java.call(reference, JavaAPI.webGoBack) }
    func goForward() { Java.call(reference, JavaAPI.webGoForward) }
    func reload() { Java.call(reference, JavaAPI.webReload) }

    /// Runs `script` in the page; what it evaluated to answers the act waiting under `ticket`.
    func evaluate(_ script: String, ticket: Int64) {
        Java.frame { Java.call(reference, JavaAPI.webEvaluate, .object(Java.string(script)), .long(ticket)) }
    }

    func navigating(cause: Int32, to address: String) {
        onNavigating?(WebNavigationEvent(rawValue: cause) ?? .unknown, address)
    }

    func navigated(result: Int32, cause: Int32, to address: String) {
        onNavigated?(
            WebNavigationResult(rawValue: result) ?? .unknown, WebNavigationEvent(rawValue: cause) ?? .unknown, address)
    }

    /// The history as it stands: a flag that changed is said.
    func history(back: Bool, forward: Bool) {
        if back != canGoBack {
            canGoBack = back
            onCanGoBack?(back)
        }
        if forward != canGoForward {
            canGoForward = forward
            onCanGoForward?(forward)
        }
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
