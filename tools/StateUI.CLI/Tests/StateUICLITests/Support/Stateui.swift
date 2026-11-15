// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import Synchronization
import XCTest
#if os(Windows)
import WinSDK
#endif

/// The built `stateui`, run as a user runs it.
enum Stateui {
    /// The program's path among the package's products.
    static var path: String { product("stateui") }

    /// The test program `ProcessProbe`'s path, which plays a program the tool runs.
    static var probe: String { product("ProcessProbe") }

    private static func product(_ name: String) -> String {
        #if os(macOS)
        let products = Bundle.allBundles.first { $0.bundlePath.hasSuffix(".xctest") }!.bundleURL
            .deletingLastPathComponent()
        #else
        let products = Bundle.main.bundleURL
        #endif
        #if os(Windows)
        return products.appendingPathComponent(name + ".exe").path
        #else
        return products.appendingPathComponent(name).path
        #endif
    }

    /// The process identifier the probe's descendant wrote to `file`, waited for.
    static func identifier(writtenTo file: URL) throws -> Int32 {
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline {
            if let text = try? String(contentsOf: file, encoding: .utf8), let identifier = Int32(text) { return identifier }
            Thread.sleep(forTimeInterval: 0.05)
        }
        throw XCTSkip("the probe wrote no process identifier")
    }

    /// Whether the process `identifier` still runs: on Linux an ended one no init has reaped - in a container - does
    /// not.
    static func runs(_ identifier: Int32) -> Bool {
        #if os(Windows)
        guard let process = OpenProcess(0x0010_0000, false, DWORD(identifier)) else { return false }
        defer { CloseHandle(process) }
        return WaitForSingleObject(process, 0) == 258
        #elseif os(Linux)
        guard let stat = try? String(contentsOfFile: "/proc/\(identifier)/stat", encoding: .utf8),
              let name = stat.lastIndex(of: ")") else { return false }
        return stat[stat.index(after: name)...].first { $0 != " " } != "Z"
        #else
        return kill(identifier, 0) == 0
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
