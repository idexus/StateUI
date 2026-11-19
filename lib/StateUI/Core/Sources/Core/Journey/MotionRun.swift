// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A movement `move(to:)` started: its one result, to be awaited apart from its start.
// Design: docs/design/core/journeys.md#a-movements-result

/// A movement as `move(to:)` answers it - started already, or refused; `result()`
/// waits for how it ends.
///
///     let fading = $fade.journey.move(to: 0)
///     if try await fading.result() == .reached(.animated) { … }
///
/// Every movement ends exactly once. A run nobody awaits ends all the same.
@MainActor
public final class MotionRun {
    /// How it ended, or nil while it is under way. Read at any time; a body
    /// reading it is not rebuilt when it changes.
    public private(set) var outcome: MotionResult?

    /// Who waits for the end, each under a number of its own, so a cancelled one leaves alone.
    private var waiting: [(number: Int, continuation: CheckedContinuation<MotionResult?, Never>)] = []

    /// The number the next waiter waits under.
    private var nextWaiter = 0

    /// A movement under way, the host to answer its end.
    init() {
        Self.open += 1
    }

    /// A movement that ended as it began: refused, or there already.
    init(ended result: MotionResult) {
        outcome = result
    }

    /// How many movements are under way - what a test of leaks counts.
    static private(set) var open = 0

    /// Waits for the movement's end and answers how it ended. Once ended, it
    /// answers at once, as often as asked. A task cancelled while it waits
    /// stops waiting; the movement goes on for whoever else waits, and
    /// `stop()` is what ends it.
    ///
    /// - Throws: `CancellationError` where the waiting task is cancelled.
    @discardableResult
    public func result() async throws -> MotionResult {
        if let outcome { return outcome }

        let number = nextWaiter
        nextWaiter += 1
        let end = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<MotionResult?, Never>) in
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
        // Design: docs/design/core/journeys.md#a-movements-result
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

    /// Ends the movement with its one result; a second word is no word.
    func end(_ result: MotionResult) {
        guard outcome == nil else { return }

        outcome = result
        Self.open -= 1
        let resumed = waiting
        waiting.removeAll()
        Renderer.shared.resumesPending += resumed.count

        for waiter in resumed {
            waiter.continuation.resume(returning: result)
        }
    }

    /// The host's answer to the waiter this run was booked under.
    func land(_ reply: Reply) {
        switch reply {
        case .finished(let values):
            end(values.first?.number.flatMap(Self.result(coded:)) ?? .reached(.animated))
        case .failed, .cancelled:
            // The host went, or the application's end took the waiter: nothing shows the state.
            end(.detached)
        }
    }

    /// An outcome as the number a host's answer carries, and back.
    static func code(of outcome: HostMotionOutcome) -> Double {
        switch outcome {
        case .animated: 0
        case .immediate(.alreadyAtDestination): 1
        case .immediate(.motionDisabled): 2
        case .immediate(.reducedMotion): 3
        case .superseded: 4
        case .stopped: 5
        case .detached: 6
        }
    }

    private static func result(coded code: Double) -> MotionResult? {
        switch code {
        case 0: .reached(.animated)
        case 1: .reached(.immediate(.alreadyAtDestination))
        case 2: .reached(.immediate(.motionDisabled))
        case 3: .reached(.immediate(.reducedMotion))
        case 4: .superseded
        case 5: .stopped
        case 6: .detached
        default: nil
        }
    }
}
