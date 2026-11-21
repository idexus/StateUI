// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One end and who waits for it: said once, heard by every waiter, each under a number of its own so one whose
/// task was cancelled leaves alone.
/// Design: docs/design/core/journeys.md#a-movements-result
@MainActor
final class Awaited<Value: Sendable> {
    /// The end, or nil while nobody said it.
    private(set) var outcome: Value?

    private var waiting: [(number: Int, continuation: CheckedContinuation<Value?, Never>)] = []
    private var nextWaiter = 0

    /// An end nobody said yet.
    init() {}

    /// An end said already.
    init(ended value: Value) {
        outcome = value
    }

    /// Waits for the end and answers it; said already, it answers at once, as often as asked.
    /// - Throws: `CancellationError` where the waiting task is cancelled.
    func value() async throws -> Value {
        if let outcome { return outcome }

        let number = nextWaiter
        nextWaiter += 1
        let end = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Value?, Never>) in
                if Task.isCancelled {
                    Renderer.shared.resumesPending += 1
                    continuation.resume(returning: nil)
                } else {
                    waiting.append((number, continuation))
                }
            }
        } onCancel: {
            libraryTask { self.letGo(number) }
        }
        // Counted as each waiter is resumed, lowered as it runs again - whatever it carries.
        Renderer.shared.resumesPending -= 1
        guard let end else { throw CancellationError() }
        return end
    }

    /// A waiter whose task was cancelled, let go with its cancellation; one already resumed is gone.
    private func letGo(_ number: Int) {
        guard let place = waiting.firstIndex(where: { $0.number == number }) else { return }

        let waiter = waiting.remove(at: place)
        Renderer.shared.resumesPending += 1
        waiter.continuation.resume(returning: nil)
    }

    /// Says the end; a second word is no word. Whether this was the first.
    @discardableResult
    func end(_ value: Value) -> Bool {
        guard outcome == nil else { return false }

        outcome = value
        let resumed = waiting
        waiting.removeAll()
        Renderer.shared.resumesPending += resumed.count
        for waiter in resumed {
            waiter.continuation.resume(returning: value)
        }
        return true
    }
}
