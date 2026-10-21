// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import WebKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A WebView as Apple's hosts register it and answer its acts.
/// Design: docs/design/platforms/apple/web.md#a-web-view
extension WebKitView {
    /// Registers a WebView in `registry`: the page it shows and what it calls itself, and what the page does.
    public static func register<View: AnyObject>(in registry: Registry<View>) {
        registry.add(WebViewContract.self, create: { reports in
            let web = WebKitView()
            web.onNavigating = { event, address in reports.raise(WebViewContract.navigating, event, address) }
            web.onNavigated = { result, event, address in
                reports.raise(WebViewContract.navigated, result, event, address)
            }
            web.onCanGoBack = { can in reports.raise(WebViewContract.canGoBackChanged, can) }
            web.onCanGoForward = { can in reports.raise(WebViewContract.canGoForwardChanged, can) }
            web.onProcessGone = { reports.raise(WebViewContract.processTerminated) }
            return web
        }, members: { web in
            web.applies(WebViewContract.userAgent, WebViewContract.source) { view, values in
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
    public static let acts: [any ContractMember] = [
        WebViewContract.evaluateJavaScript, WebViewContract.goBack, WebViewContract.goForward, WebViewContract.reload,
    ]

    /// Performs `call`, one of `acts`, answering it through `core`: a step at once, a script with what it evaluated
    /// to, as text.
    public func perform(_ call: HostActCall, through core: CoreLink) {
        switch call.act {
        case .goBack: step(.back)
        case .goForward: step(.forward)
        case .reload: step(.reload)
        default:
            return evaluate(call.arguments.value(1)?.string ?? "") { answer in core.reply(call, [answer.propValue]) }
        }
        core.reply(call, [])
    }
}
