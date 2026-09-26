// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AndroidRegistrations {
    /// A WebView: the page it shows and what it calls itself, and what the page does.
    static func web(_ registry: Registry<AndroidView>) {
        registry.add(WebViewContract.self, create: { reports in
            let web = AndroidWebView()
            web.onNavigating = { event, address in reports.raise(WebViewContract.navigating, event, address) }
            web.onNavigated = { result, event, address in
                reports.raise(WebViewContract.navigated, result, event, address)
            }
            web.onCanGoBack = { can in reports.raise(WebViewContract.canGoBackChanged, can) }
            web.onCanGoForward = { can in reports.raise(WebViewContract.canGoForwardChanged, can) }
            web.onProcessGone = { reports.raise(WebViewContract.processTerminated) }
            return web
        }, members: { web in
            web.applies([WebViewContract.userAgent, WebViewContract.source]) { view, values in
                if values.changed(WebViewContract.source) {
                    view.show(values[WebViewContract.source], userAgent: values[WebViewContract.userAgent])
                } else if values.changed(WebViewContract.userAgent) {
                    view.setUserAgent(values[WebViewContract.userAgent])
                }
            }
            web.raises(WebViewContract.navigating)
            web.raises(WebViewContract.navigated)
            web.raises(WebViewContract.canGoBackChanged)
            web.raises(WebViewContract.canGoForwardChanged)
            web.raises(WebViewContract.processTerminated)
        })
    }
}
