// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A WebView: WinUI's WebView2. What the page does comes back as the element's events - why a navigation began and
/// when a way back or forward opens, by the host layer's rules.
/// Design: docs/design/platforms/winui/controls.md#a-web-view
@MainActor
final class WinUIWebView: WinUIView {
    /// What the view does when a navigation starts: why, and where it goes.
    var onNavigating: ((WebNavigationEvent, String) -> Void)?

    /// What the view does when a navigation ends: how, why, and where it went.
    var onNavigated: ((WebNavigationResult, WebNavigationEvent, String) -> Void)?

    /// What the view does when there comes to be, or stops being, a page behind it and ahead of it.
    var onCanGoBack: ((Bool) -> Void)?
    var onCanGoForward: ((Bool) -> Void)?

    /// What the view does when its web process ended, leaving it blank.
    var onProcessGone: (() -> Void)?

    private var cause = WebNavigationCause()
    private var history = WebHistory()

    /// How many documents with no address of their own it was given: each is shown at an address of its own.
    private var written = 0

    /// The page last asked for - its address, and the document written in place there - and whether a navigation
    /// is under way.
    private var asked: (address: String, document: String?, agent: String)?
    private var loading = false

    init() {
        super.init { number in stateui_winui_web_make(number) }
    }

    /// Shows the page at an address, or a document written in place - at its own address, else at one the host
    /// gives it - asking as `agent`, the runtime's own for none; no source leaves the page as it is.
    /// Design: docs/design/platforms/winui/controls.md#a-web-view
    func show(_ source: WebViewSource?, userAgent agent: String?) {
        let asking = agent ?? ""
        switch source {
        case .url(let address)?: go((address, nil, asking))
        case .html(let document, let base?)?: go((base, document, asking))
        case .html(let document, nil)?:
            written += 1
            go((Self.documentAddress(number, written), document, asking))
        case nil: stateui_winui_web_set_agent(handle, number, asking)
        }
    }

    private func go(_ page: (address: String, document: String?, agent: String)) {
        asked = page
        if let document = page.document {
            stateui_winui_web_show(handle, number, page.address, document, page.agent)
        } else {
            stateui_winui_web_show(handle, number, page.address, nil, page.agent)
        }
    }

    /// Where the view `view` shows its `count`th document with no address of its own: a name no network answers.
    static func documentAddress(_ view: Int64, _ count: Int) -> String {
        "https://page.stateui.invalid/\(view)/\(count)"
    }

    /// What the view calls itself to a server from the next page on; none for the runtime's own.
    func setUserAgent(_ agent: String?) {
        stateui_winui_web_set_agent(handle, number, agent ?? "")
    }

    /// Steps back or forward, or loads the page again - the navigation's cause the program's step. A page still
    /// coming WebView2 does not load again: it is asked for again instead.
    func step(_ step: WebNavigationEvent) {
        cause.ask(step)
        if step == .refresh, loading, let asked { return go(asked) }
        stateui_winui_web_step(handle, step.rawValue)
    }

    /// Runs `script` in the page; the JSON of what it evaluated to answers under `ticket`.
    func evaluate(_ script: String, ticket: Int64) {
        stateui_winui_web_evaluate(handle, script, ticket)
    }

    func navigating(told: WebNavigationEvent, to address: String) {
        loading = true
        onNavigating?(cause.begin(told: told), address)
    }

    func navigated(_ result: WebNavigationResult, at address: String) {
        loading = false
        onNavigated?(result, cause.current, address)
    }

    func historyChanged(back: Bool, forward: Bool) {
        let changed = history.changes(back: back, forward: forward)
        if let back = changed.back { onCanGoBack?(back) }
        if let forward = changed.forward { onCanGoForward?(forward) }
    }

    func ended() {
        onProcessGone?()
    }

    override func detach() {
        super.detach()
        onNavigating = nil
        onNavigated = nil
        onCanGoBack = nil
        onCanGoForward = nil
        onProcessGone = nil
        stateui_winui_web_release(number)
    }
}
