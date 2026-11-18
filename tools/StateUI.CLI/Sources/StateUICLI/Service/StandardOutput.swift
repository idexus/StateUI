// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
import Foundation
import StateUITooling
import Synchronization

/// This process's standard output as one writer: each frame written whole, in the order given, and the bytes given
/// but not yet written counted - what a client that stops reading leaves.
/// Design: docs/design/tooling/protocol.md#a-client-that-reads-too-slowly
final class StandardOutput: Sendable {
    private let queue = DispatchQueue(label: "stateui standard output")
    private let unwritten = Mutex(0)

    init() {
        BrokenPipe.ignore()
    }

    /// Writes `frame` after every frame given before it.
    @Sendable func write(_ frame: Data) {
        unwritten.withLock { $0 += frame.count }
        queue.async { [self] in
            try? FileHandle.standardOutput.write(contentsOf: frame)
            unwritten.withLock { $0 -= frame.count }
        }
    }

    /// The bytes given but not yet written.
    @Sendable func backlog() -> Int {
        unwritten.withLock { $0 }
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
