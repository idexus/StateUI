// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The act calls a host is handed for a web view, each by the real typed call:
// the act's name, the view at 0, then each argument in its place, and whether
// a caller waits for the answer.

import XCTest
@_spi(Host) @testable import StateUI
import StateUIWebView

final class WebViewActTests: XCTestCase {
    private typealias Act = nonisolated(nonsending) () async throws -> Void

    /// One act a caller waits for, made by `body`: taken, held to its name and arguments, then answered.
    private func check(
        _ act: String, _ arguments: [PropValue], file: StaticString = #filePath, line: UInt = #line,
        _ body: sending @escaping Act
    ) async throws {
        drainedActs()
        let task = await MainActor.run { Task.immediate { @MainActor in try await body() } }
        let batch = drainedActs()

        XCTAssertEqual(batch.map(\.act.name), [act], file: file, line: line)
        XCTAssertEqual(batch.first?.arguments, arguments, file: file, line: line)
        XCTAssertNotNil(batch.first?.completion, "a caller waits for it", file: file, line: line)

        if let id = batch.compactMap(\.completion).first {
            HostBoundary.reply(id, with: [.bool(true)])
            await settle()
        }
        _ = try? await task.value
    }

    /// The three acts without an argument of their own carry the view alone, each by its name.
    func testTheWaysAndTheReloadCrossWithTheViewAlone() async throws {
        try await check("goBack", [.string("browser")]) { try await named("browser", WebView.self).goBack() }
        try await check("goForward", [.string("browser")]) { try await named("browser", WebView.self).goForward() }
        try await check("reload", [.string("browser")]) { try await named("browser", WebView.self).reload() }
    }

    /// A script crosses after the view, and its answer is waited for.
    func testAScriptCrossesAfterTheView() async throws {
        try await check("evaluateJavaScript", [.string("browser"), .string("document.title")]) {
            _ = try await named("browser", WebView.self).evaluateJavaScript("document.title")
        }
    }
}
