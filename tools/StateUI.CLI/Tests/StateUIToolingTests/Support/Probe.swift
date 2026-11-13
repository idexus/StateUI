// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import Synchronization
import XCTest
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif os(Windows)
import WinSDK
#endif

/// The test program `ProcessProbe`, run through the runner.
enum Probe {
    /// The directory the package's products are built into.
    static var products: URL {
        #if os(macOS)
        for bundle in Bundle.allBundles where bundle.bundlePath.hasSuffix(".xctest") {
            return bundle.bundleURL.deletingLastPathComponent()
        }
        fatalError("no test bundle is loaded")
        #else
        return Bundle.main.bundleURL
        #endif
    }

    /// The probe's path.
    static var path: String {
        #if os(Windows)
        products.appendingPathComponent("ProcessProbe.exe").path
        #else
        products.appendingPathComponent("ProcessProbe").path
        #endif
    }

    /// A request running the probe with `arguments`.
    static func request(_ arguments: String..., timeout: Duration? = .seconds(60)) -> ProcessRequest {
        ProcessRequest(.path(path), arguments: arguments, timeout: timeout)
    }

    /// Runs `request` and gives its outcome with every line it wrote, in the order each stream wrote them.
    static func run(_ request: ProcessRequest) async throws -> (outcome: ProcessOutcome, lines: Lines) {
        let lines = Lines()
        let outcome = try await ProcessRunner().run(request) { lines.add($0) }
        return (outcome, lines)
    }

    /// Whether the process `identifier` still runs.
    static func isRunning(_ identifier: Int32) -> Bool {
        #if os(Windows)
        guard let handle = OpenProcess(DWORD(PROCESS_QUERY_LIMITED_INFORMATION), false, DWORD(identifier)) else {
            return false
        }
        defer { CloseHandle(handle) }
        var code: DWORD = 0
        return GetExitCodeProcess(handle, &code) && code == DWORD(STILL_ACTIVE)
        #else
        return kill(identifier, 0) == 0 || errno == EPERM
        #endif
    }

    /// Waits up to `limit` for the process `identifier` to be gone; whether it went.
    static func waitUntilGone(_ identifier: Int32, limit: Duration = .seconds(10)) async throws -> Bool {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if !isRunning(identifier) { return true }
            try await Task.sleep(for: .milliseconds(50))
        }
        return false
    }

    /// Waits up to `limit` for a process identifier to be written into `file`.
    static func identifier(writtenTo file: URL, limit: Duration = .seconds(20)) async throws -> Int32 {
        let deadline = ContinuousClock.now + limit
        while ContinuousClock.now < deadline {
            if let text = try? String(contentsOf: file, encoding: .utf8), let identifier = Int32(text) {
                return identifier
            }
            try await Task.sleep(for: .milliseconds(50))
        }
        throw XCTSkip("no process identifier was written to \(file.path)")
    }

    /// Ends the process `identifier`, which a test left behind.
    static func end(_ identifier: Int32) {
        #if os(Windows)
        if let handle = OpenProcess(DWORD(PROCESS_TERMINATE), false, DWORD(identifier)) {
            TerminateProcess(handle, 1)
            CloseHandle(handle)
        }
        #else
        kill(identifier, SIGKILL)
        #endif
    }

    /// A fresh directory for one test.
    static func directory(_ name: String = "probe") throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("stateui-cli-tests-\(UUID().uuidString)")
            .appendingPathComponent(name)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }
}

/// The lines a run wrote, gathered from the runner's two streams.
final class Lines: Sendable {
    private let gathered = Mutex<[ProcessOutput]>([])

    func add(_ line: ProcessOutput) {
        gathered.withLock { $0.append(line) }
    }

    /// The lines of `stream`, in order.
    func of(_ stream: ProcessOutput.Stream) -> [String] {
        gathered.withLock { $0.filter { $0.stream == stream }.map(\.text) }
    }
}
