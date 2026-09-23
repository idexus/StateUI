// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The act queue: the acts the application sends, the completions waiting for an
// answer, and the receipt of the batch the host took.
// Design: docs/design/core/acts.md#completion-ids

extension Renderer {
    /// Registers a waiter for an animation's end and answers the id written on its
    /// image - the counter every awaited act draws from.
    /// Design: docs/design/core/journeys.md#moving-and-waiting
    func book(_ completion: @escaping (Reply) -> Void) -> Int {
        guarded.withLock { () -> Int in
            let issued = nextCompletionId

            completions[issued] = completion
            nextCompletionId -= 1

            return issued
        }
    }

    /// The completions nobody has answered yet - what a test playing the host answers.
    var waiting: [Int] { guarded.withLock { Array(completions.keys) } }

    /// Queues an act by its token, the library's or an application's.
    func send(_ act: Act, _ arguments: [PropValue], completion: ((Reply) -> Void)?) {
        enqueue({ ActCall(act: act, arguments: arguments, completion: $0) }, completion)
    }

    /// Queues a library act nobody waits on, its arguments as its member declares.
    func send<Owner: Contract, each Argument: HostRepresentable, Answer>(
        _ act: ElementAct<Owner, (repeat each Argument), Answer>,
        _ arguments: repeat each Argument
    ) {
        send(act.token, MemberValues.encode(repeat each arguments), completion: nil)
    }

    /// Queues an act. Callable from any thread: `async let` children send from the pool.
    private func enqueue(_ make: (Int?) -> ActCall, _ completion: ((Reply) -> Void)?) {
        guarded.withLock {
            var id: Int?

            if let completion = completion {
                id = nextCompletionId
                completions[nextCompletionId] = completion
                nextCompletionId -= 1
            }

            actCalls.append(make(id))
        }

        // Wakes the host outside the lock: an act sent from a plain `Task` lands no job
        // on the executor, and nothing else would tell the host it is there.
        UIThreadExecutor.shared.poke()
    }

    /// Acts queued and not yet taken, waiting saves included - work to the doorbell.
    var actCallsPending: Int {
        // A save waiting is an act the moment it is taken (Persistence.swift).
        guarded.withLock { actCalls.count } + PersistentStore.shared.pending
            + Scenes.shared.pendingSaves
    }

    /// Queues an act and suspends until the host answers, running and resuming on
    /// the caller's executor. Throws `StateUIError` with the host's reason.
    /// Design: docs/design/core/acts.md#awaiting-an-answer
    nonisolated(nonsending) func call(
        _ act: Act,
        _ arguments: [PropValue] = []
    ) async throws -> [PropValue] {
        try await answered { self.send(act, arguments, completion: $0) }
    }

    /// The suspension itself: queues through `send`, waits for the reply, and
    /// turns its two arms into a return and a throw.
    nonisolated(nonsending) func answered(
        _ send: (@escaping (Reply) -> Void) -> Void
    ) async throws -> [PropValue] {
        let reply = await withCheckedContinuation { (continuation: CheckedContinuation<Reply, Never>) in
            send { outcome in
                // Counted here and lowered first thing after the resume, so a host can tell a
                // resume still landing from nothing to wait for.
                Renderer.shared.guarded.withLock { Renderer.shared.resumes += 1 }
                continuation.resume(returning: outcome)
            }
        }

        // On a pool thread when the caller was a child task, hence the lock.
        guarded.withLock { resumes -= 1 }

        switch reply {
        case .finished(let values):
            return values
        case .failed(let message):
            throw StateUIError(message: message)
        }
    }

    /// Reports a handler that threw, as an ordinary act.
    func report(_ error: Error) {
        send(ApplicationContract.handlerFailed, String(describing: error))
    }

    /// Hands the queued acts to the host as bytes, keeping the batch's completion
    /// ids as a receipt. An empty queue answers no bytes.
    /// Design: docs/design/core/acts.md#the-receipt
    func takeActCallsWire() -> [UInt8] {
        let batch = takeActCalls()
        return batch.isEmpty ? [] : Wire.encode(batch, dictionary: wireDictionary)
    }

    /// Hands the queued acts over typed; a Swift host answers each by its id.
    func takeActCalls() -> [ActCall] {
        // Saves become acts here, one per key per take with the last value.
        // Design: docs/design/core/state.md#kept-state
        let saves = PersistentStore.shared.takeWaiting().map {
            ActCall(ApplicationContract.persistValue, Name($0.name), $0.value)
        }

        let queued = guarded.withLock {
            let queued = actCalls
            actCalls.removeAll(keepingCapacity: true)
            takenCompletions = queued.compactMap { $0.completion }
            return queued
        }

        // And what the open scenes keep, the same way (Scenes.swift).
        return queued + saves + Scenes.shared.takeSaves()
    }

    /// Fails every act of the last taken batch, which the host could not read: each
    /// awaiting handler throws instead of waiting for ever.
    /// Design: docs/design/core/acts.md#the-receipt
    func failTakenActCalls(_ reason: String) {
        let ids = guarded.withLock {
            let ids = takenCompletions
            takenCompletions = []
            return ids
        }

        for id in ids {
            // The two steps the export takes for a reply from the host.
            ReplyBuffer.current = .failed(reason)
            _ = dispatch(id)
        }
    }
}
