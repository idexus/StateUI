// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
import StateUIUIKit
import StateUIWebView

/// The web view's UIKit backend: WebKit's web view, realized through the UIKit host's registration of an
/// application's own views.
@MainActor
public enum StateUIWebViewUIKit {
    /// Registers the web view with the UIKit host - its view, the members it takes and tells, and its four acts. Said
    /// once, from the application's UIKit head, before `StateUIUIKit.run(resourceDirectory:)`.
    ///
    ///     StateUIWebViewUIKit.register()
    public static func register() {
        StateUIControls.add(WebViewContract.self, create: { reports -> UIKitWebView in
            let web = UIKitWebView()
            web.onNavigating = { event, address in reports.raise(WebViewContract.navigating, event, address) }
            web.onNavigated = { result, event, address in
                reports.raise(WebViewContract.navigated, result, event, address)
            }
            web.onCanGoBack = { can in reports.raise(WebViewContract.canGoBackChanged, can) }
            web.onCanGoForward = { can in reports.raise(WebViewContract.canGoForwardChanged, can) }
            web.onProcessGone = { reports.raise(WebViewContract.processTerminated) }
            return web
        }) { web in
            web.property(WebViewContract.userAgent) { view, agent in view.agent = agent }
            web.property(WebViewContract.source) { view, source in view.show(source) }
            web.raises(WebViewContract.navigating)
            web.raises(WebViewContract.navigated)
            web.raises(WebViewContract.canGoBackChanged)
            web.raises(WebViewContract.canGoForwardChanged)
            web.raises(WebViewContract.processTerminated)
        }
        StateUIActs.add(WebViewContract.goBack, on: UIKitWebView.self) { web in web.step(.back) }
        StateUIActs.add(WebViewContract.goForward, on: UIKitWebView.self) { web in web.step(.forward) }
        StateUIActs.add(WebViewContract.reload, on: UIKitWebView.self) { web in web.step(.refresh) }
        StateUIActs.add(WebViewContract.evaluateJavaScript, on: UIKitWebView.self) { web, script in
            await withCheckedContinuation { answer in web.evaluate(script) { answer.resume(returning: $0) } }
        }
    }
}
#endif
