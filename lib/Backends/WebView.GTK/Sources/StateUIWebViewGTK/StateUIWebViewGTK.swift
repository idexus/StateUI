// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIGTK
import StateUI

/// The web view's GTK backend: WebKitGTK's web view, realized through the GTK host's registration of an application's
/// own controls.
@MainActor
public enum StateUIWebViewGTK {
    /// Registers the web view with the GTK host - its control, the members it takes and tells, and its four acts.
    /// Said once, from the application's GTK head, before `StateUIGTK.run(applicationID:)`.
    ///
    ///     StateUIWebViewGTK.register()
    ///     exit(StateUIGTK.run(applicationID: "com.example.App"))
    public static func register() {
        StateUIControls.add(WebViewContract.self, create: { reports -> GTKWebView in
            let web = GTKWebView()
            web.onNavigating = { event, address in reports.raise(WebViewContract.navigating, event, address) }
            web.onNavigated = { result, event, address in
                reports.raise(WebViewContract.navigated, result, event, address)
            }
            web.onCanGoBack = { can in reports.raise(WebViewContract.canGoBackChanged, can) }
            web.onCanGoForward = { can in reports.raise(WebViewContract.canGoForwardChanged, can) }
            web.onProcessGone = { reports.raise(WebViewContract.processTerminated) }
            return web
        }) { web in
            web.property(WebViewContract.userAgent) { control, agent in control.userAgent = agent }
            web.property(WebViewContract.source) { control, source in control.show(source) }
            web.raises(WebViewContract.navigating)
            web.raises(WebViewContract.navigated)
            web.raises(WebViewContract.canGoBackChanged)
            web.raises(WebViewContract.canGoForwardChanged)
            web.raises(WebViewContract.processTerminated)
        }
        StateUIActs.add(WebViewContract.goBack, on: GTKWebView.self) { web in web.step(.back) }
        StateUIActs.add(WebViewContract.goForward, on: GTKWebView.self) { web in web.step(.forward) }
        StateUIActs.add(WebViewContract.reload, on: GTKWebView.self) { web in web.step(.refresh) }
        StateUIActs.add(WebViewContract.evaluateJavaScript, on: GTKWebView.self) { web, script in
            try await web.evaluate(script)
        }
    }
}
