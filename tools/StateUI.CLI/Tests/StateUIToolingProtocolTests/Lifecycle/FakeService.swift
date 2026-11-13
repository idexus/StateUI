// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIToolingProtocol
import Synchronization

/// A service of a few methods whose answers a test controls.
final class FakeService: Sendable {
    struct Text: Codable, Sendable { var text: String }
    struct Failure: Error {}
    struct Work: Codable, Sendable {
        var steps: Int
        var output: String?
        var errorBytes: Int?
        var holds: Bool?
        var fails: Bool?
    }
    struct Done: Codable, Sendable { var steps: Int }

    /// Opens when the test lets `test/slow` answer.
    let gate = Gate()
    /// How many times `test/count` ran.
    let counted = Mutex(0)
    /// Opens when the test lets a holding `test/work` end.
    let hold = Gate()

    var methods: Methods {
        var methods = Methods()
        methods.query("test/echo") { (text: Text) in text }
        methods.query("test/slow") { (text: Text) in await self.gate.wait(); return text }
        methods.query("test/refuse") { (_: NoParameters) -> NoParameters in
            throw ToolingError(.notFound, "No such thing.")
        }
        methods.query("test/fail") { (_: NoParameters) -> NoParameters in throw Failure() }
        methods.query("test/count") { (_: NoParameters) in self.counted.withLock { $0 += 1 }; return NoParameters() }
        methods.mutation("test/work") { (work: Work, context: OperationContext) -> Done in
            for step in 1...max(work.steps, 1) {
                await context.progress(OperationProgress(stage: "step", completed: step, total: work.steps))
            }
            if let output = work.output { await context.output(Array(output.utf8), on: .stdout) }
            if let count = work.errorBytes { await context.output(Array(repeating: 0x78, count: count), on: .stderr) }
            if work.holds == true {
                while await !self.hold.isOpen { try await Task.sleep(for: .milliseconds(5)) }
            }
            if work.fails == true { throw ToolingError(.notFound, "Gone.") }
            return Done(steps: work.steps)
        }
        return methods
    }
}

/// A gate tasks wait at until it opens.
actor Gate {
    private(set) var isOpen = false
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        guard !isOpen else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func release() {
        isOpen = true
        waiting.forEach { $0.resume() }
        waiting.removeAll()
    }
}
