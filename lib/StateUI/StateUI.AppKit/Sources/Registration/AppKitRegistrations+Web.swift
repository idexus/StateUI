// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension AppKitRegistrations {
    /// A WebView: the page it shows and what it calls itself, and what the page does.
    static func web(_ registry: Registry<NSView>) {
        registry.add(WebViewContract.self, create: { reports in
            let web = AppKitWebView()
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
                view.show(
                    values.changed(WebViewContract.source) ? values[WebViewContract.source] : nil,
                    userAgent: values[WebViewContract.userAgent])
            }
            web.raises(WebViewContract.navigating)
            web.raises(WebViewContract.navigated)
            web.raises(WebViewContract.canGoBackChanged)
            web.raises(WebViewContract.canGoForwardChanged)
            web.raises(WebViewContract.processTerminated)
        })
    }

    /// The acts a web view answers itself, beside the ones every host performs.
    static let webActs: [any ContractMember] = [
        WebViewContract.evaluateJavaScript, WebViewContract.goBack, WebViewContract.goForward, WebViewContract.reload,
    ]
}
#endif
