// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@testable import StateUIWinUI
@testable import StateUIWinUIDriver
@testable import StateUIWebViewWinUI

/// The WinUI host's backends, registered as an application's head registers them, each with what the driver reaches
/// of its control - so the families run on them as on the host's own controls.
/// Design: docs/design/host/conformance.md#a-backends-element
enum WinUIBackends {
    /// Every backend registered, once.
    @MainActor static let registered: Void = {
        StateUIWebViewWinUI.register()
        WinUIDriver.backends[WebViewContract.nodeType] = WinUIBackendDriving(
            contract: WebViewContract.self,
            held: { property, view in
                guard let web = (view as? WinUIHostedView<WinUIWebView>)?.control else { return nil }
                switch property {
                case WebViewContract.source.token: return .some(web.shownSource.propValue)
                case WebViewContract.userAgent.token: return .some(.string(web.read("agent")))
                default: return nil
                }
            },
            perform: { act, view in
                guard act == .endContent, let web = (view as? WinUIHostedView<WinUIWebView>)?.control else {
                    return false
                }
                // The processes drawing its pages stand a moment after the view is asked for a page.
                for _ in 0..<200 {
                    if web.endContent() { return true }
                    WinUITestHost.pump(0.1)
                }
                return false
            })
    }()
}
