// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIAndroid
import StateUIWebView

/// The web view's Android backend: Android's web view, realized through the Android host's registration of an
/// application's own controls. Its Java half, in this package's Java folder, is compiled into the application's APK by
/// the application's own build.
@MainActor
public enum StateUIWebViewAndroid {
    /// Registers the web view with the Android host - its control, the members it takes and tells, and its four acts.
    /// Said once, from the application's Android head as its library loads, before `StateUIAndroid.load(_:)`.
    ///
    ///     StateUIWebViewAndroid.register()
    public static func register() {
        StateUIControls.add(WebViewContract.self, create: { reports -> AndroidWebView in
            let web = AndroidWebView()
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
        StateUIActs.add(WebViewContract.goBack, on: AndroidWebView.self) { web in web.goBack() }
        StateUIActs.add(WebViewContract.goForward, on: AndroidWebView.self) { web in web.goForward() }
        StateUIActs.add(WebViewContract.reload, on: AndroidWebView.self) { web in web.reload() }
        StateUIActs.add(WebViewContract.evaluateJavaScript, on: AndroidWebView.self) { web, script in
            await web.evaluate(script)
        }
    }
}
