// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
import Foundation
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// This process's standard output as one writer: each frame written whole, in the order given.
/// Design: docs/design/tooling/protocol.md#a-connections-life
final class StandardOutput: Sendable {
    private let queue = DispatchQueue(label: "stateui standard output")

    init() {
        #if !os(Windows)
        signal(SIGPIPE, SIG_IGN)
        #endif
    }

    /// Writes `frame` after every frame given before it.
    @Sendable func write(_ frame: Data) {
        queue.async { try? FileHandle.standardOutput.write(contentsOf: frame) }
    }

    /// Returns once every frame given is written.
    func flush() {
        queue.sync {}
    }

    /// Writes a diagnostic on standard error, which no client reads as a message.
    @Sendable static func diagnose(_ line: String) {
        try? FileHandle.standardError.write(contentsOf: Data((line + "\n").utf8))
    }
}
