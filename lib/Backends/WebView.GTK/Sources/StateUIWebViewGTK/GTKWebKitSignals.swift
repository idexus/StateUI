// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIGTK
import CWebKitGTK
@_spi(Host) import StateUIHost

/// What WebKit tells a web view, reaching it through a link it holds weakly: a signal the widget raises after its
/// view is gone reaches nothing.
/// Design: docs/design/platforms/gtk/controls.md#a-web-view
@MainActor
enum GTKWebKitSignals {
    /// The view a signal reaches, while it lives.
    final class Link {
        weak var view: GTKWebView?

        init(_ view: GTKWebView) {
            self.view = view
        }
    }

    /// Connects WebKit's signals of `view`'s web view, and of its list of pages, to `view`.
    static func connect(_ view: GTKWebView) {
        let link = Link(view)
        let decided: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?)
            -> Int32 = { _, decision, type, data in
                // Only a navigation's action says why it began; WebKit decides as it would without this.
                guard type == 0, let decision, let action = webkit_navigation_policy_decision_get_navigation_action(decision)
                else { return 0 }
                let navigationType = webkit_navigation_action_get_navigation_type(action)
                MainActor.assumeIsolated { GTKWebKitSignals.reached(data)?.decided(navigationType) }
                return 0
            }
        let changed: @convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?) -> Void = { _, event, data in
            MainActor.assumeIsolated { GTKWebKitSignals.reached(data)?.loadChanged(event) }
        }
        let failed: @convention(c) (
            UnsafeMutableRawPointer?, Int32, UnsafePointer<CChar>?, UnsafeMutablePointer<GError>?, UnsafeMutableRawPointer?
        ) -> Int32 = { _, _, address, error, data in
            // WEBKIT_NETWORK_ERROR_CANCELLED: the load was called off.
            let cancelled = error?.pointee.code == 302
            MainActor.assumeIsolated { GTKWebKitSignals.reached(data)?.loadFailed(address.map { String(cString: $0) } ?? "", cancelled: cancelled) }
            return 0
        }
        let ended: @convention(c) (UnsafeMutableRawPointer?, Int32, UnsafeMutableRawPointer?) -> Void = { _, _, data in
            MainActor.assumeIsolated { GTKWebKitSignals.reached(data)?.processGone() }
        }
        let pagesChanged: @convention(c) (
            UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?
        ) -> Void = { _, _, _, data in
            MainActor.assumeIsolated { GTKWebKitSignals.reached(data)?.historyChanged() }
        }

        let web = view.webView
        connect(web, "decide-policy", unsafeBitCast(decided, to: GCallback.self), link)
        connect(web, "load-changed", unsafeBitCast(changed, to: GCallback.self), link)
        connect(web, "load-failed", unsafeBitCast(failed, to: GCallback.self), link)
        connect(web, "web-process-terminated", unsafeBitCast(ended, to: GCallback.self), link)
        if let pages = webkit_web_view_get_back_forward_list(web) {
            connect(pages, "changed", unsafeBitCast(pagesChanged, to: GCallback.self), link)
        }
    }

    /// Loads `view`'s page once GLib's loop is idle: after the element's values are all applied.
    static func whenIdle(_ view: GTKWebView) {
        let load: @convention(c) (UnsafeMutableRawPointer?) -> Int32 = { data in
            MainActor.assumeIsolated { Unmanaged<Link>.fromOpaque(data!).takeUnretainedValue().view?.loadPending() }
            return 0
        }
        g_idle_add_full(
            G_PRIORITY_DEFAULT_IDLE, load, Unmanaged.passRetained(Link(view)).toOpaque(),
            { data in Unmanaged<Link>.fromOpaque(data!).release() })
    }

    /// Runs `script` in `view`'s page, answering what it evaluated to as text; throws what WebKit says went wrong.
    static func evaluate(_ script: String, in view: GTKWebView) async throws -> String? {
        try await withCheckedThrowingContinuation { (answer: CheckedContinuation<String?, any Error>) in
            let done: @convention(c) (UnsafeMutableRawPointer?, UnsafeMutableRawPointer?, UnsafeMutableRawPointer?)
                -> Void = { source, result, data in
                    let answer = Unmanaged<Answer>.fromOpaque(data!).takeRetainedValue()
                    var error: UnsafeMutableRawPointer?
                    guard let value = webkit_web_view_evaluate_javascript_finish(source, result, &error) else {
                        let failure = error?.assumingMemoryBound(to: GError.self)
                        let message = failure?.pointee.message.map { String(cString: $0) } ?? "the script answered nothing"
                        if let failure { g_error_free(failure) }
                        return answer.continuation.resume(throwing: ScriptFailed(message: message))
                    }
                    let json = jsc_value_to_json(value, 0)
                    defer { g_free(json) }
                    g_object_unref(value)
                    answer.continuation.resume(returning: ScriptAnswer.text(json: json.map { String(cString: $0) }))
                }
            webkit_web_view_evaluate_javascript(
                view.webView, script, -1, nil, nil, nil, done, Unmanaged.passRetained(Answer(answer)).toOpaque())
        }
    }

    /// What a script's run is answered through.
    private final class Answer {
        let continuation: CheckedContinuation<String?, any Error>

        init(_ continuation: CheckedContinuation<String?, any Error>) {
            self.continuation = continuation
        }
    }

    /// What WebKit said went wrong in a script.
    struct ScriptFailed: Error, CustomStringConvertible {
        let message: String
        var description: String { "the script failed: \(message)" }
    }

    /// The view `data`, a link, reaches; nil once it is gone.
    private static func reached(_ data: UnsafeMutableRawPointer?) -> GTKWebView? {
        data.flatMap { Unmanaged<Link>.fromOpaque($0).takeUnretainedValue().view }
    }

    /// Connects `handler` to `instance`'s `signal`, handing it `link`, held until the handler is let go.
    private static func connect(_ instance: UnsafeMutableRawPointer, _ signal: String, _ handler: GCallback, _ link: Link) {
        g_signal_connect_data(
            instance, signal, handler, Unmanaged.passRetained(link).toOpaque(),
            { data, _ in data.map { Unmanaged<Link>.fromOpaque($0).release() } }, GConnectFlags(rawValue: 0))
    }
}
