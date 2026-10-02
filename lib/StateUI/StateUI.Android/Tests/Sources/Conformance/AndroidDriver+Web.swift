// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Android
import CStateUIAndroid
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
@testable import StateUIAndroid
@_spi(Host) import StateUIConformance

/// What the Android driver reads and does of a web view: the address and the agent Android's web view holds, and
/// its web process ended as the platform ends it.
/// Design: docs/design/platforms/android/conformance.md#what-the-driver-reads
extension AndroidDriver {
    static func webHolds(_ property: Prop, _ view: AndroidWebView) throws -> HostValue?? {
        switch property {
        case .userAgent:
            return .some(Java.frame {
                onWeb(view) { web in
                    Java.callObject(web, getSettings).flatMap { Java.callObject($0, getUserAgentString) }.map { Java.text($0) }
                } ?? nil
            }?.propValue)
        case .source:
            // A document with no address of its own from the `data:` address holding it.
            let address = Java.frame { onWeb(view) { web in Java.callObject(web, getUrl).map { Java.text($0) } } ?? nil }
            guard let address else { return .some(nil) }
            let shown = WebDocument.document(at: address).map { WebViewSource.html($0, baseURL: nil) } ?? .url(address)
            return .some(shown.propValue)
        default: return nil
        }
    }

    /// Ends the web view's web process, as the platform ends one.
    static func endContent(of view: AndroidWebView) throws {
        let ended = Java.frame {
            onWeb(view) { web in
                guard let process = Java.callObject(web, getWebViewRenderProcess) else { return false }
                return Java.callBool(process, terminate)
            } ?? false
        }
        guard ended else { throw DriverCannot("end a web process", because: "Android's web view gave back none to end") }
    }

    /// `act` on the Android web view the host's holder holds.
    private static func onWeb<Result>(_ view: AndroidWebView, _ act: (jobject) -> Result) -> Result? {
        Java.jni.GetObjectField(Java.env, view.reference, web).map(act)
    }

    static let web = Java.field(JavaAPI.webView, "web", "Landroid/webkit/WebView;")
    static let androidWebView = Java.findClass("android/webkit/WebView")
    static let getUrl = Java.method(androidWebView, "getUrl", "()Ljava/lang/String;")
    static let getSettings = Java.method(androidWebView, "getSettings", "()Landroid/webkit/WebSettings;")
    static let getUserAgentString = Java.method(
        Java.findClass("android/webkit/WebSettings"), "getUserAgentString", "()Ljava/lang/String;")
    static let getWebViewRenderProcess = Java.method(
        androidWebView, "getWebViewRenderProcess", "()Landroid/webkit/WebViewRenderProcess;")
    static let terminate = Java.method(Java.findClass("android/webkit/WebViewRenderProcess"), "terminate", "()Z")
}
