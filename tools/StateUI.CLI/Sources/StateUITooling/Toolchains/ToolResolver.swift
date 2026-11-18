// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation

/// The programs the tool runs, found the one way every operation and `doctor` find them.
public struct ToolResolver: Sendable {
    private let environment: [String: String]

    /// A resolver reading `environment`: this process's own unless given.
    public init(environment: [String: String] = ProcessInfo.processInfo.environment) {
        self.environment = environment
    }

    /// Swift: the compiler `SWIFT_BIN` names, else `swift` on the search path.
    public var swift: ProcessExecutable {
        environment["SWIFT_BIN"].flatMap { $0.isEmpty ? nil : .path($0) } ?? .name("swift")
    }

    /// Git, on the search path.
    public var git: ProcessExecutable { .name("git") }

    /// The Swift toolchain's `lldb-dap`: beside `swift` - its links followed - else on the search path; nil where none
    /// stands.
    var lldbDap: URL? { toolchainProgram("lldb-dap") }

    /// The Swift toolchain's program `name`: beside `swift` - its links followed - else on the search path.
    private func toolchainProgram(_ name: String) -> URL? {
        let path = SearchPath(environment: environment)
        if let swift = (environment["SWIFT_BIN"].map { URL(fileURLWithPath: $0) } ?? path.find("swift"))?.resolvingSymlinksInPath() {
            #if os(Windows)
            let beside = swift.deletingLastPathComponent().appendingPathComponent(name + ".exe")
            #else
            let beside = swift.deletingLastPathComponent().appendingPathComponent(name)
            #endif
            if FileManager.default.fileExists(atPath: beside.path) { return beside }
        }
        return path.find(name)
    }
}
