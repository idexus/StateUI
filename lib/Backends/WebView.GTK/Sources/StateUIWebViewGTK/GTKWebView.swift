// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import CWebKitGTK
import StateUIGTK
import StateUI
@_spi(Host) import StateUIHost

/// A WebView on GTK: WebKitGTK's own web view, telling what its page does by the host layer's web rules.
/// Design: docs/design/platforms/gtk/controls.md#a-web-view
@MainActor
final class GTKWebView: GTKControl {
    let widget: UnsafeMutablePointer<GtkWidget>

    /// What the view tells: a navigation beginning, one ending, the ways back and forward as they change, and its
    /// web process gone.
    var onNavigating: ((WebNavigationType, String) -> Void)?
    var onNavigated: ((WebNavigationResult, WebNavigationType, String) -> Void)?
    var onCanGoBack: ((Bool) -> Void)?
    var onCanGoForward: ((Bool) -> Void)?
    var onProcessGone: (() -> Void)?

    /// The page last asked for, which WebKit gives back as an address alone.
    private(set) var source: WebViewSource?

    private var history = WebHistory()
    private var cause = WebNavigationCause()

    /// Why the navigation WebKit decides on next began, as its action says.
    private var told = WebNavigationType.newPage

    /// Whether the navigation under way failed, so its finish tells nothing more.
    private var failed = false

    /// A page asked for and not loaded yet: loaded once the element's values are all applied.
    private var pending: WebViewSource?

    init() {
        widget = webkit_web_view_new()!.assumingMemoryBound(to: GtkWidget.self)
        g_object_ref_sink(widget)
        GTKWebKitSignals.connect(self)
    }

    isolated deinit {
        g_object_unref(widget)
    }

    /// WebKit's web view, as WebKit's calls take it.
    var webView: UnsafeMutableRawPointer { UnsafeMutableRawPointer(widget) }

    // MARK: - What the tree gives it

    /// Shows `source` - once the element's other values, its agent among them, are applied.
    func show(_ source: WebViewSource?) {
        guard let source, source != self.source else { return }
        self.source = source
        if pending == nil { GTKWebKitSignals.whenIdle(self) }
        pending = source
    }

    /// Loads the page asked for last.
    func loadPending() {
        guard let pending else { return }
        self.pending = nil
        switch pending {
        case .url(let address): webkit_web_view_load_uri(webView, address)
        case .html(let document, let baseURL?): webkit_web_view_load_html(webView, document, baseURL)
        case .html(let document, nil): webkit_web_view_load_uri(webView, WebDocument.address(of: document))
        }
    }

    /// What the view calls itself to the servers it asks; nil for WebKit's own.
    var userAgent: String? {
        get { webkit_settings_get_user_agent(webkit_web_view_get_settings(webView)).map { String(cString: $0) } }
        set { webkit_settings_set_user_agent(webkit_web_view_get_settings(webView), newValue) }
    }

    // MARK: - Its acts

    /// Takes the program's step - back, forward, the page again - which the navigation it begins is told as.
    func step(_ step: WebNavigationType) {
        cause.ask(step)
        switch step {
        case .back: webkit_web_view_go_back(webView)
        case .forward: webkit_web_view_go_forward(webView)
        default: webkit_web_view_reload(webView)
        }
    }

    /// Runs `script` in the page, answering what it evaluated to as text (`ScriptAnswer`).
    func evaluate(_ script: String) async throws -> String? {
        try await GTKWebKitSignals.evaluate(script, in: self)
    }

    /// Ends the web process under the view, as the system does when memory runs short.
    func endWebProcess() {
        webkit_web_view_terminate_web_process(webView)
    }

    // MARK: - What WebKit tells

    /// WebKit decides on a navigation: what its action says it is.
    func decided(_ navigationType: Int32) {
        told = switch navigationType {
        case NavigationType.reload: .reload
        case NavigationType.backForward: .unknown
        default: .newPage
        }
    }

    /// A load moved on: it began, its page came, or it ended.
    func loadChanged(_ event: Int32) {
        let address = webkit_web_view_get_uri(webView).map { String(cString: $0) } ?? ""
        switch event {
        case LoadEvent.started:
            failed = false
            let event = cause.begin(told: told)
            told = .newPage
            onNavigating?(event, address)
        case LoadEvent.finished where !failed:
            onNavigated?(.success, cause.current, address)
        default:
            break
        }
        historyChanged()
    }

    /// A load failed: called off, or not fetched.
    func loadFailed(_ address: String, cancelled: Bool) {
        failed = true
        onNavigated?(cancelled ? .cancelled : .failure, cause.current, address)
    }

    /// The pages behind and ahead may have changed: each way said as it changes (`WebHistory`).
    func historyChanged() {
        let changes = history.changes(
            back: webkit_web_view_can_go_back(webView) != 0, forward: webkit_web_view_can_go_forward(webView) != 0)
        if let back = changes.back { onCanGoBack?(back) }
        if let forward = changes.forward { onCanGoForward?(forward) }
    }

    /// The web process under the view ended.
    func processGone() {
        onProcessGone?()
    }

    /// WebKit's `WebKitLoadEvent` cases the view tells.
    private enum LoadEvent {
        static let started: Int32 = 0
        static let finished: Int32 = 3
    }

    /// WebKit's `WebKitNavigationType` cases the view tells apart.
    private enum NavigationType {
        static let backForward: Int32 = 2
        static let reload: Int32 = 3
    }
}
