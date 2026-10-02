// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CWebViewWinUI
import StateUIWinUI
import StateUI
@_spi(Host) import StateUIHost

/// A WebView on WinUI: WinUI's WebView2, made by the backend's relay. What the page does comes back as the element's
/// events - why a navigation began and when a way back or forward opens, by the host layer's web rules.
/// Design: docs/design/platforms/winui/controls.md#a-web-view
@MainActor
final class WinUIWebView: WinUIControl {
    let element: OpaquePointer

    /// What the view tells: a navigation beginning, one ending, the ways back and forward as they change, and its
    /// web process gone.
    var onNavigating: ((WebNavigationEvent, String) -> Void)?
    var onNavigated: ((WebNavigationResult, WebNavigationEvent, String) -> Void)?
    var onCanGoBack: ((Bool) -> Void)?
    var onCanGoForward: ((Bool) -> Void)?
    var onProcessGone: (() -> Void)?

    private var cause = WebNavigationCause()
    private var history = WebHistory()
    private let number: Int64

    /// How many documents with no address of their own it was given: each is shown at an address of its own.
    private var written = 0

    /// What the view calls itself; the page last asked for - its address, and the document written in place there -
    /// and whether a navigation is under way; and a page not loaded yet, loaded once the element's values are applied.
    private var agent = ""
    private var asked: (address: String, document: String?)?
    private var loading = false
    private var pending: WebViewSource?
    private var loaded: WebViewSource?

    init() {
        WinUIWebViewRelay.listen()
        number = WinUIWebViewRelay.reserve()
        element = stateui_webview_winui_make(number)!
        WinUIWebViewRelay.hold(self, as: number)
    }

    isolated deinit {
        WinUIWebViewRelay.forget(number)
        stateui_webview_winui_release(element, number)
    }

    // MARK: - What the tree gives it

    /// What the view calls itself to a server from the next page on; nil for the runtime's own.
    func setUserAgent(_ agent: String?) {
        self.agent = agent ?? ""
        stateui_webview_winui_set_agent(element, number, self.agent)
    }

    /// Shows the page at an address, or a document written in place - at its own address, else at one the backend
    /// gives it - once the element's other values are applied; no source leaves the page as it is.
    func show(_ source: WebViewSource?) {
        guard let source else { return }
        if pending == nil { Task { @MainActor [weak self] in self?.loadPending() } }
        pending = source
    }

    private func loadPending() {
        guard let source = pending else { return }
        pending = nil
        loaded = source
        switch source {
        case .url(let address): go((address, nil))
        case .html(let document, let base?): go((base, document))
        case .html(let document, nil):
            written += 1
            go((Self.documentAddress(number, written), document))
        }
    }

    private func go(_ page: (address: String, document: String?)) {
        asked = page
        if let document = page.document {
            stateui_webview_winui_show(element, number, page.address, document, agent)
        } else {
            stateui_webview_winui_show(element, number, page.address, nil, agent)
        }
    }

    /// Where the view `view` shows its `count`th document with no address of its own: a name no network answers.
    static func documentAddress(_ view: Int64, _ count: Int) -> String {
        "https://page.stateui.invalid/\(view)/\(count)"
    }

    // MARK: - Its acts

    /// Steps back or forward, or loads the page again - the navigation's cause the program's step. A page still
    /// coming WebView2 does not load again: it is asked for again instead.
    func step(_ step: WebNavigationEvent) {
        cause.ask(step)
        if step == .refresh, loading, let asked { return go(asked) }
        stateui_webview_winui_step(element, step.rawValue)
    }

    /// Runs `script` in the page, answering what it evaluated to as text (`ScriptAnswer`); throws where it did not
    /// run.
    func evaluate(_ script: String) async throws -> String? {
        try await withCheckedThrowingContinuation { answer in
            stateui_webview_winui_evaluate(element, script, WinUIWebViewRelay.wait(answer))
        }
    }

    // MARK: - What a test reads

    /// What WebView2 holds of the view - "address" the page's, "document" the one written in place it shows there,
    /// "agent" what it calls itself.
    func read(_ what: String) -> String {
        let length = Int(stateui_webview_winui_read(element, number, what, nil, 0))
        var bytes = [CChar](repeating: 0, count: length + 1)
        _ = bytes.withUnsafeMutableBufferPointer {
            stateui_webview_winui_read(element, number, what, $0.baseAddress, Int32($0.count))
        }
        return String(decoding: bytes.prefix(length).map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }

    /// The page the view shows: the document last written in place where WebView2 stands at the address answering
    /// it, else the address it stands at.
    var shownSource: WebViewSource {
        if case .html(let document, _)? = loaded, let loaded, read("document") == document { return loaded }
        return .url(read("address"))
    }

    /// Ends the processes drawing its pages, as the system ends a web process; whether any was ended.
    func endContent() -> Bool {
        stateui_webview_winui_end_content(element)
    }

    // MARK: - What the page does

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
}
