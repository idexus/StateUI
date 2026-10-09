// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A movement `move(to:)` started: its end, to be awaited apart from its start.
// Design: docs/design/core/journeys.md#moving-and-waiting

/// A movement under way, as `move(to:)` answers it - started already; `arrived()`
/// waits for its end.
///
///     let fading = $fade.journey.move(to: 0)
///     try await fading.arrived()
@MainActor
public final class Arrival {
    /// How it ended, once it has.
    private var outcome: Result<Bool, any Error>?

    /// Who waits for the end.
    private var waiting: [CheckedContinuation<Bool, any Error>] = []

    /// How it ended - whether it got there - or nil while it is under way: what a
    /// test asks without waiting.
    var ended: Bool? { try? outcome?.get() }

    /// A movement under way, the host to answer its end.
    init() {}

    /// A movement that ended as it began: there already, or never under way.
    init(at end: Bool) {
        outcome = .success(end)
    }

    /// Waits for the end, and answers whether the value got there: true when it ran
    /// to the end, false when something else ended it - a newer destination, a
    /// value written over it, or `stop()`. Once ended, answers at once, as often as
    /// asked.
    ///
    /// - Throws: whatever the host answers when it cannot carry the value at all.
    @discardableResult
    public func arrived() async throws -> Bool {
        if let outcome { return try outcome.get() }

        let end = try await withCheckedThrowingContinuation { waiting.append($0) }

        // Counted as the host answered, lowered as the waiter runs again.
        // Design: docs/design/core/acts.md#awaiting-an-answer
        Renderer.shared.resumes -= 1
        return end
    }

    /// The host's answer: the end, or why it could not carry the value.
    func land(_ reply: Reply) {
        switch reply {
        case .finished(let values):
            outcome = .success(values.first?.bool ?? true)
        case .failed(let message):
            outcome = .failure(StateUIError(message: message))
        }

        let resumed = waiting
        waiting.removeAll()
        Renderer.shared.resumes += resumed.count

        for continuation in resumed {
            continuation.resume(with: outcome!)
        }
    }
}
