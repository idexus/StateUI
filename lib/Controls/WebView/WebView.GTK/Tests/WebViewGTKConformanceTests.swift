// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CWebKitGTK
import Foundation
import XCTest
@_spi(Host) import StateUI
@_spi(Host) import StateUIConformance
@testable import StateUIGTK
@testable import StateUIGTKDriver
import StateUIWebView
@_spi(Host) import StateUIWebViewConformance
@testable import StateUIWebViewGTK

/// The web view's families on GTK - its own, and each of a tier it wears, for it alone - through GTK's driver; the
/// verdicts stand in the component's own exports.
final class WebViewGTKConformanceTests: XCTestCase {
    /// The component's folder, two above this file's: its exports, and its family's revisions.
    private static let exports = GTKExports.component(
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent(), named: "WebView")

    override func setUp() {
        onUIThread { Self.registered }
    }

    /// The backend registered with GTK, the web view among the specimens, and its driver beside GTK's: once.
    @MainActor private static let registered: Void = {
        StateUIWebViewGTK.register()
        WebViewTests.addSpecimen()
        GTKDriver.components[WebViewContract.nodeType] = GTKComponentDriving(
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
                webkit_web_view_terminate_web_process(web.webView)
                return true
            },
            byHost: [
                "read source of WebView": "the page the backend last asked for: WebKit gives back an address, never the "
                    + "document written",
            ])
    }()

    func testWebView() { conform(WebViewTests.self) }

    func testTheTiersItWears() {
        for tier in WebViewContract.worn where tier.name != WebViewContract.name {
            guard let family = Families.all.first(where: { $0.name == tier.name }) else {
                return XCTFail("no family of \(tier.name)")
            }
            conform(family, element: "WebView")
        }
    }

    private func conform(_ family: any ConformanceFamily.Type, element: String? = nil) {
        onUIThread { Self.exports.conform(family, element: element) }
    }
}
