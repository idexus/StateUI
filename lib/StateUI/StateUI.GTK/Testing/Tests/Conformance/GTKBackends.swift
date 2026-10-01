// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
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
                guard let web = (view as? GTKHostedView<GTKWebKitView>)?.control else { return nil }
                switch property {
                case WebViewContract.source.token: return .some(web.source?.propValue)
                case WebViewContract.userAgent.token: return .some(web.userAgent.map { .string($0) })
                default: return nil
                }
            },
            perform: { act, view in
                guard act == .endContent, let web = (view as? GTKHostedView<GTKWebKitView>)?.control else { return false }
                web.endWebProcess()
                return true
            },
            byHost: [
                "read source of WebView": "the page the backend last asked for: WebKit gives back an address, never the "
                    + "document written",
            ])
    }()
}
