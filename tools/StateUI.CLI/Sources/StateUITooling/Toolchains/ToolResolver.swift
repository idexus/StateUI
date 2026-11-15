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
}
