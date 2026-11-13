// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import Synchronization
import XCTest

/// The built `stateui`, run as a user runs it.
enum Stateui {
    /// The program's path among the package's products.
    static var path: String {
        #if os(macOS)
        let products = Bundle.allBundles.first { $0.bundlePath.hasSuffix(".xctest") }!.bundleURL
            .deletingLastPathComponent()
        #else
        let products = Bundle.main.bundleURL
        #endif
        #if os(Windows)
        return products.appendingPathComponent("stateui.exe").path
        #else
        return products.appendingPathComponent("stateui").path
        #endif
    }

    /// Runs `stateui` with `arguments`: its outcome, standard output and standard error.
    static func run(_ arguments: String...) async throws -> (ProcessOutcome, [String], [String]) {
        try await run(arguments)
    }

    /// Runs `stateui` with `arguments`: its outcome, standard output and standard error.
    static func run(_ arguments: [String]) async throws -> (ProcessOutcome, [String], [String]) {
        XCTAssertTrue(FileManager.default.fileExists(atPath: path), "stateui is not built at \(path)")
        let lines = Mutex<[ProcessOutput]>([])
        let outcome = try await ProcessRunner().run(
            ProcessRequest(.path(path), arguments: arguments, timeout: .seconds(60))
        ) { line in lines.withLock { $0.append(line) } }
        let written = lines.withLock { $0 }
        return (
            outcome,
            written.filter { $0.stream == .standardOutput }.map(\.text),
            written.filter { $0.stream == .standardError }.map(\.text)
        )
    }
}
