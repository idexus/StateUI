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

    /// Who waits for the end, each under a number of its own, so a cancelled one leaves alone.
    private var waiting: [(number: Int, continuation: CheckedContinuation<Result<Bool, any Error>, Never>)] = []

    /// The number the next waiter waits under.
    private var nextWaiter = 0

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
    /// asked. A task cancelled while it waits stops waiting, and the movement goes
    /// on for whoever else waits: `stop()` ends it.
    ///
    /// - Throws: `CancellationError` where the waiting task is cancelled; whatever
    ///   the host answers when it cannot carry the value at all.
    @discardableResult
    public func arrived() async throws -> Bool {
        if let outcome { return try outcome.get() }

        let number = nextWaiter
        nextWaiter += 1
        let end = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Result<Bool, any Error>, Never>) in
                if Task.isCancelled {
                    Renderer.shared.resumesPending += 1
                    continuation.resume(returning: .failure(CancellationError()))
                } else {
                    waiting.append((number, continuation))
                }
            }
        } onCancel: {
            libraryTask { self.letGo(number) }
        }

        // Counted as each waiter is resumed, lowered as it runs again - whatever it carries.
        // Design: docs/design/core/journeys.md#moving-and-waiting
        Renderer.shared.resumesPending -= 1
        return try end.get()
    }

    /// A waiter whose task was cancelled, let go with its cancellation; one already resumed is gone.
    private func letGo(_ number: Int) {
        guard let place = waiting.firstIndex(where: { $0.number == number }) else { return }

        let waiter = waiting.remove(at: place)
        Renderer.shared.resumesPending += 1
        waiter.continuation.resume(returning: .failure(CancellationError()))
    }

    /// The host's answer: the end, or why it could not carry the value.
    func land(_ reply: Reply) {
        switch reply {
        case .finished(let values):
            outcome = .success(values.first?.bool ?? true)
        case .failed(let message):
            outcome = .failure(StateUIError.notPerformed(act: "move", reason: message))
        case .cancelled:
            outcome = .failure(CancellationError())
        }

        let resumed = waiting
        waiting.removeAll()
        Renderer.shared.resumesPending += resumed.count

        for waiter in resumed {
            waiter.continuation.resume(returning: outcome!)
        }
    }
}
