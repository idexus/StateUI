// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
@testable import StateUITooling
import StateUIToolingProtocol
import XCTest

final class BackendRuntimeTests: XCTestCase {
    /// The web view's backend declares WebView2's component and loader, from the pinned package, for the
    /// architecture built for.
    func testTheWebViewBackendDeclaresWebView2sComponentAndLoader() throws {
        let backend = ProjectReaderTests.repository.appendingPathComponent("lib/Backends/WebView.WinUI")
        let runtimes = try BackendRuntime.declared(in: [backend, ProjectReaderTests.repository.appendingPathComponent("lib/StateUI")])
        XCTAssertEqual(runtimes, [BackendRuntime(backend: "WebView.WinUI", files: [
            .init(package: "microsoft.web.webview2", source: "runtimes/win-{architecture}/native_uap/Microsoft.Web.WebView2.Core.dll",
                  destination: "Microsoft.Web.WebView2.Core.dll"),
            .init(package: "microsoft.web.webview2", source: "runtimes/win-{architecture}/native/WebView2Loader.dll",
                  destination: "WebView2Loader.dll"),
        ])])
        XCTAssertEqual(BackendRuntime.word(for: .x86_64), "x64")
        XCTAssertEqual(BackendRuntime.word(for: .arm64), "arm64")
    }

    /// A line is three words of a pinned package and paths inside their folders; anything else is said, with its line.
    func testADeclarationIsRefusedWhereItLeavesItsRules() {
        let refused = [
            "microsoft.web.webview2 a.dll",
            "some.package a.dll a.dll",
            "microsoft.web.webview2 ../a.dll a.dll",
            "microsoft.web.webview2 a.dll ..\\a.dll",
            "microsoft.web.webview2 /a.dll a.dll",
            "microsoft.web.webview2 a.dll C:/a.dll",
            "microsoft.web.webview2 a.dll {architecture}/a.dll",
        ]
        for line in refused {
            XCTAssertThrowsError(try BackendRuntime.parse("# a comment\n\(line)\n", backend: "Bad.WinUI"), line) { error in
                XCTAssertEqual((error as? ToolingError)?.code, .invalidConfiguration)
                XCTAssertTrue((error as? ToolingError)?.message.contains("line 2") ?? false, "\(error)")
            }
        }
    }

    /// Two backends laying one file from different sources fail before anything is laid; the same file twice is one.
    func testTwoSourcesForOneDestinationAreRefused() throws {
        let one = BackendRuntime(backend: "A.WinUI", files: [.init(package: "microsoft.web.webview2", source: "a/x.dll", destination: "X.dll")])
        let same = BackendRuntime(backend: "B.WinUI", files: [.init(package: "microsoft.web.webview2", source: "a/x.dll", destination: "x.dll")])
        let other = BackendRuntime(backend: "C.WinUI", files: [.init(package: "microsoft.web.webview2", source: "b/x.dll", destination: "x.DLL")])
        XCTAssertNoThrow(try BackendRuntime.check([one, same]))
        XCTAssertThrowsError(try BackendRuntime.check([one, other])) { error in
            XCTAssertTrue((error as? ToolingError)?.message.contains("A.WinUI and C.WinUI") ?? false, "\(error)")
        }
    }
}
