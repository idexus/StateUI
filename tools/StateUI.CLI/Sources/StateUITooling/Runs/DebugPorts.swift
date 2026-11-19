// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol
import Synchronization

/// The ports of this machine's loopback an `lldb-server` of a run holds now: the only ones a paired client's relay
/// reaches through the service.
/// Design: docs/design/tooling/service.md#a-debugger-relayed
enum DebugPorts {
    private static let held = Mutex<Set<UInt16>>([])

    /// A port of the loopback no program listens on now, for an `lldb-server` to take.
    static func free() throws(ToolingError) -> UInt16 {
        let socket = try StreamSocket.listen(on: "127.0.0.1", port: 0)
        defer { socket.close() }
        return socket.port
    }

    /// Holds `port` while `work` runs: relayed to while it lasts, no longer.
    static func holding<Result>(_ port: UInt16, _ work: () async throws -> Result) async rethrows -> Result {
        held.withLock { _ = $0.insert(port) }
        defer { held.withLock { _ = $0.remove(port) } }
        return try await work()
    }

    /// Whether a run's `lldb-server` holds `port` now.
    static func holds(_ port: UInt16) -> Bool {
        held.withLock { $0.contains(port) }
    }
}
