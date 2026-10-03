// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIGTK
@testable import StateUIGTKDriver
@testable import StateUIWebViewGTK

/// The GTK host's backends, registered as an application's head registers them, each with what the driver reaches of
/// its widget - so the families run on them as on the host's own controls.
/// Design: docs/design/host/conformance.md#a-backends-element
enum GTKBackends {
    /// Every backend registered, once.
    @MainActor static let registered: Void = {
        StateUIWebViewGTK.register()
        GTKDriver.backends[WebViewContract.nodeType] = GTKBackendDriving(
            contract: WebViewContract.self,
            held: { property, view in
                guard let web = (view as? GTKHostedView<GTKWebView>)?.control else { return nil }
                switch property {
                case WebViewContract.source.token: return .some(shown(by: web)?.propValue)
                case WebViewContract.userAgent.token: return .some(web.userAgent.map { .string($0) })
                default: return nil
                }
            },
            perform: { act, view in
                guard act == .endContent, let web = (view as? GTKHostedView<GTKWebView>)?.control else { return false }
                web.endWebProcess()
                return true
            },
            byHost: [:])
    }()

    /// What a web view shows, by the address WebKit gives back: a document with no address of its own from the
    /// `data:` address holding it.
    @MainActor private static func shown(by web: GTKWebView) -> WebViewSource? {
        guard let address = web.address else { return nil }
        return WebDocument.document(at: address).map { .html($0, baseURL: nil) } ?? .url(address)
    }
}
