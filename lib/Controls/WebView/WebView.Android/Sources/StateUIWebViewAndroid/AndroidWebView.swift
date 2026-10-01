// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import StateUIAndroid
import StateUIWebView
@_spi(Host) import StateUIWebViewHost

/// A WebView on Android: Android's own web view, in the component's `StateUIWebView`, which makes it again should
/// its web process die. What the page does comes back as the element's events; a history flag only when it changes.
/// Design: docs/design/platforms/android/controls.md#a-web-view
@MainActor
final class AndroidWebView: AndroidControl {
    let view: JavaObject

    /// What the view tells: a navigation beginning, one ending, the ways back and forward as they change, and its
    /// web process gone.
    var onNavigating: ((WebNavigationEvent, String) -> Void)?
    var onNavigated: ((WebNavigationResult, WebNavigationEvent, String) -> Void)?
    var onCanGoBack: ((Bool) -> Void)?
    var onCanGoForward: ((Bool) -> Void)?
    var onProcessGone: (() -> Void)?

    private var history = WebHistory()
    private let number: Int64

    /// What the view calls itself, and a page asked for and not loaded yet: loaded once the element's values are all
    /// applied, so it is asked for as the agent the tree gives.
    private var agent: String?
    private var pending: WebViewSource?

    init() {
        AndroidWebViewNatives.register()
        number = AndroidWebViewNatives.reserve()
        view = Java.new(Self.viewClass, Self.make, .object(StateUIAndroid.context), .long(number))
        AndroidWebViewNatives.hold(self, as: number)
    }

    isolated deinit {
        AndroidWebViewNatives.forget(number)
        Java.call(view.reference, Self.release)
    }

    // MARK: - What the tree gives it

    /// What the view calls itself to a server from the next page on; nil for the platform's own.
    func setUserAgent(_ agent: String?) {
        self.agent = agent
        Java.frame { Java.call(view.reference, Self.setAgent, .object(agent.flatMap(Java.string))) }
    }

    /// Shows the page at an address, or a document written in place - once the element's other values are applied;
    /// no source leaves the view as it is.
    func show(_ source: WebViewSource?) {
        guard let source else { return }
        if pending == nil { Task { @MainActor [weak self] in self?.loadPending() } }
        pending = source
    }

    /// Loads the page asked for last, as the agent the view names itself by.
    private func loadPending() {
        guard let source = pending else { return }
        pending = nil
        Java.frame {
            let agent = agent.flatMap(Java.string)
            switch source {
            case .url(let address):
                Java.call(view.reference, Self.load, .object(agent), .object(Java.string(address)))
            case .html(let document, let base):
                Java.call(
                    view.reference, Self.showDocument, .object(agent), .object(Java.string(document)),
                    .object(base.flatMap(Java.string)))
            }
        }
    }

    // MARK: - Its acts

    func goBack() { Java.call(view.reference, Self.back) }
    func goForward() { Java.call(view.reference, Self.forward) }
    func reload() { Java.call(view.reference, Self.again) }

    /// Runs `script` in the page, answering what it evaluated to, as text; nothing for no value.
    func evaluate(_ script: String) async -> String? {
        await withCheckedContinuation { answer in
            let ticket = AndroidWebViewNatives.wait(answer)
            Java.frame { Java.call(view.reference, Self.run, .object(Java.string(script)), .long(ticket)) }
        }
    }

    // MARK: - What the page does

    func navigating(cause: Int32, to address: String) {
        onNavigating?(WebNavigationEvent(rawValue: cause) ?? .unknown, address)
    }

    func navigated(result: Int32, cause: Int32, to address: String) {
        onNavigated?(
            WebNavigationResult(rawValue: result) ?? .unknown, WebNavigationEvent(rawValue: cause) ?? .unknown, address)
    }

    /// The history as it stands: each way said as it changes (`WebHistory`).
    func historyChanged(back: Bool, forward: Bool) {
        let changes = history.changes(back: back, forward: forward)
        if let back = changes.back { onCanGoBack?(back) }
        if let forward = changes.forward { onCanGoForward?(forward) }
    }

    func processGone() {
        onProcessGone?()
    }

    // MARK: - The Java half

    private static let viewClass = Java.findClass("stateui/webview/StateUIWebView")
    private static let make = Java.method(viewClass, "<init>", "(Landroid/content/Context;J)V")
    private static let load = Java.method(viewClass, "load", "(Ljava/lang/String;Ljava/lang/String;)V")
    private static let showDocument = Java.method(
        viewClass, "show", "(Ljava/lang/String;Ljava/lang/String;Ljava/lang/String;)V")
    private static let setAgent = Java.method(viewClass, "setUserAgent", "(Ljava/lang/String;)V")
    private static let back = Java.method(viewClass, "goBack", "()V")
    private static let forward = Java.method(viewClass, "goForward", "()V")
    private static let again = Java.method(viewClass, "reload", "()V")
    private static let run = Java.method(viewClass, "evaluate", "(Ljava/lang/String;J)V")
    private static let release = Java.method(viewClass, "release", "()V")
}
