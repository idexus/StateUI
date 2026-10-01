// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIWinUI
import StateUI

/// The web view's WinUI backend: WinUI's WebView2, made by this package's relay and realized through the WinUI host's
/// registration of an application's own controls.
@MainActor
public enum StateUIWebViewWinUI {
    /// Registers the web view with the WinUI host - its control, the members it takes and tells, and its four acts.
    /// Said once, from the application's WinUI head, before `StateUIWinUI.run()`.
    ///
    ///     StateUIWebViewWinUI.register()
    public static func register() {
        StateUIControls.add(WebViewContract.self, create: { reports -> WinUIWebView in
            let web = WinUIWebView()
            web.onNavigating = { event, address in reports.raise(WebViewContract.navigating, event, address) }
            web.onNavigated = { result, event, address in
                reports.raise(WebViewContract.navigated, result, event, address)
            }
            web.onCanGoBack = { can in reports.raise(WebViewContract.canGoBackChanged, can) }
            web.onCanGoForward = { can in reports.raise(WebViewContract.canGoForwardChanged, can) }
            web.onProcessGone = { reports.raise(WebViewContract.processTerminated) }
            return web
        }) { web in
            web.property(WebViewContract.userAgent) { control, agent in control.setUserAgent(agent) }
            web.property(WebViewContract.source) { control, source in control.show(source) }
            web.raises(WebViewContract.navigating)
            web.raises(WebViewContract.navigated)
            web.raises(WebViewContract.canGoBackChanged)
            web.raises(WebViewContract.canGoForwardChanged)
            web.raises(WebViewContract.processTerminated)
        }
        StateUIActs.add(WebViewContract.goBack, on: WinUIWebView.self) { web in web.step(.back) }
        StateUIActs.add(WebViewContract.goForward, on: WinUIWebView.self) { web in web.step(.forward) }
        StateUIActs.add(WebViewContract.reload, on: WinUIWebView.self) { web in web.step(.refresh) }
        StateUIActs.add(WebViewContract.evaluateJavaScript, on: WinUIWebView.self) { web, script in
            try await web.evaluate(script)
        }
    }
}
