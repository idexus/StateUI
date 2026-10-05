// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

extension WebRegistrations {
    /// A WebView: the page it shows, and what the page does - as far as the browser lets the page know.
    static func web(_ registry: Registry<WebDOMView>) {
        registry.add(WebViewContract.self, create: { reports in
            let frame = WebFrameView()
            frame.onNavigating = { event, address in reports.raise(WebViewContract.navigating, event, address) }
            frame.onNavigated = { result, event, address in
                reports.raise(WebViewContract.navigated, result, event, address)
            }
            frame.onCanGoBack = { can in reports.raise(WebViewContract.canGoBackChanged, can) }
            frame.onCanGoForward = { can in reports.raise(WebViewContract.canGoForwardChanged, can) }
            return frame
        }, members: { frame in
            frame.property(WebViewContract.source) { view, source in view.show(source) }
            frame.raises(WebViewContract.navigating)
            frame.raises(WebViewContract.navigated)
            frame.raises(WebViewContract.canGoBackChanged)
            frame.raises(WebViewContract.canGoForwardChanged)
        })
    }
}
