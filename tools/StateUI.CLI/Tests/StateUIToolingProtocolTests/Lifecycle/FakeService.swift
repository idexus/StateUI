// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol
import Synchronization

/// A service of a few methods whose answers a test controls.
final class FakeService: Sendable {
    struct Text: Codable, Sendable { var text: String }
    struct Failure: Error {}

    /// Opens when the test lets `test/slow` answer.
    let gate = Gate()
    /// How many times `test/count` ran.
    let counted = Mutex(0)

    var methods: Methods {
        var methods = Methods()
        methods.query("test/echo") { (text: Text) in text }
        methods.query("test/slow") { (text: Text) in await self.gate.wait(); return text }
        methods.query("test/refuse") { (_: NoParameters) -> NoParameters in
            throw ToolingError(.notFound, "No such thing.")
        }
        methods.query("test/fail") { (_: NoParameters) -> NoParameters in throw Failure() }
        methods.query("test/count") { (_: NoParameters) in self.counted.withLock { $0 += 1 }; return NoParameters() }
        return methods
    }
}

/// A gate tasks wait at until it opens.
actor Gate {
    private var open = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !open else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        open = true
        waiting.forEach { $0.resume() }
        waiting.removeAll()
    }
}
