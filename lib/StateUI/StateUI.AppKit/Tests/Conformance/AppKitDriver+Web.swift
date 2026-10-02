// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import WebKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAppKit
@_spi(Host) import StateUIConformance

/// A web view as WebKit holds it: the agent it names itself by, and what it shows by the address WebKit gives back.
extension AppKitDriver {
    /// What WebKit's view holds of `property`; nil for what is not the web view's.
    func webHolds(_ property: Prop, _ web: AppKitWebView) -> HostValue? {
        switch property {
        case .userAgent: web.customUserAgent.propValue
        case .source: Self.shown(by: web)?.propValue
        default: nil
        }
    }

    /// What a web view shows, by the address WebKit gives back: a document with no address of its own from the
    /// `data:` address holding it.
    private static func shown(by web: AppKitWebView) -> WebViewSource? {
        guard let address = web.url?.absoluteString else { return nil }
        return WebDocument.document(at: address).map { .html($0, baseUrl: nil) } ?? .url(address)
    }
}
#endif
