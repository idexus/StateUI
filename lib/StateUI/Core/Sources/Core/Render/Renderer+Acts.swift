// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

// The act queue: the acts the application sends, and the completions waiting
// for an answer.
// Design: docs/design/core/acts.md#completion-ids

extension Renderer {
    /// Registers a waiter for an animation's end and answers the id written on its
    /// image - the counter every awaited act draws from.
    /// Design: docs/design/core/journeys.md#moving-and-waiting
    func book(_ completion: @escaping (Reply) -> Void) -> Int {
        let issued = nextCompletionId

        completions[issued] = completion
        nextCompletionId -= 1

        return issued
    }

    /// The completions nobody has answered yet - what a test playing the host answers.
    var waiting: [Int] { Array(completions.keys) }

    /// Queues an act by its token, the library's or an application's: the id its answer comes under, where a
    /// caller waits for one.
    @discardableResult
    func send(_ act: Act, _ arguments: [PropValue], completion: ((Reply) -> Void)?) -> Int? {
        enqueue({ ActCall(act: act, arguments: arguments, completion: $0) }, completion)
    }

    /// Queues a library act nobody waits on, its arguments as its member declares.
    func send<Owner: Contract, each Argument: HostRepresentable, Answer>(
        _ act: ElementAct<Owner, (repeat each Argument), Answer>,
        _ arguments: repeat each Argument
    ) {
        send(act.token, MemberValues.encode(repeat each arguments), completion: nil)
    }

    /// Queues an act: the id its answer comes under, where a caller waits for one.
    @discardableResult
    private func enqueue(_ make: (Int?) -> ActCall, _ completion: ((Reply) -> Void)?) -> Int? {
        guard HandlerRun.admits("an act") else { return nil }

        var id: Int?

        if let completion = completion {
            id = nextCompletionId
            completions[nextCompletionId] = completion
            nextCompletionId -= 1
        }

        actCalls.append(make(id))

        // An act sent where no turn follows - an application's own callback - would wait for the next event.
        UIThreadExecutor.shared.askForTurn()
        return id
    }

    /// Acts queued and not yet taken, waiting saves included - work for a turn.
    var actCallsPending: Int {
        // A save waiting is an act the moment it is taken (Persistence.swift).
        actCalls.count + PersistentStore.shared.pending
            + OpenScenes.shared.pendingSaves
    }

    /// Queues an act and suspends until the host answers, running and resuming on
    /// the UI thread. Throws `StateUIError` with the host's reason.
    /// Design: docs/design/core/acts.md#awaiting-an-answer
    func call(
        _ act: Act,
        _ arguments: [PropValue] = []
    ) async throws -> [PropValue] {
        try await answered { self.send(act, arguments, completion: $0) }
    }

    /// The suspension itself: queues through `send`, waits for the reply, and
    /// turns its arms into a return and a throw. A caller whose task is cancelled - its run superseded, its element
    /// gone - stops waiting at once, and the host stops the call (`abandon`).
    /// Design: docs/design/core/acts.md#a-call-ends-with-its-run
    func answered(
        _ send: (@escaping (Reply) -> Void) -> Int?
    ) async throws -> [PropValue] {
        // A superseded run's act never leaves: it fails as the run's cancellation.
        guard HandlerRun.admits("an act") else { throw CancellationError() }

        let call = WaitingCall()
        let reply = await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Reply, Never>) in
                let id = send { outcome in
                    // Counted here and lowered first thing after the resume, so a host can tell a
                    // resume still landing from nothing to wait for.
                    Renderer.shared.resumesPending += 1
                    continuation.resume(returning: outcome)
                }
                call.id.withLock { $0 = id }
            }
        } onCancel: {
            libraryTask { Renderer.shared.abandon(call.id.withLock { $0 }) }
        }

        resumesPending -= 1

        switch reply {
        case .finished(let values):
            return values
        case .failed(let message):
            throw StateUIError(message: message)
        case .cancelled:
            throw CancellationError()
        }
    }

    /// The caller waiting under `id` went with its run: it hears its cancellation now, an answer coming later counts
    /// for nothing, and the host stops what it performs for it (`ApplicationContract.cancelCall`).
    /// Design: docs/design/core/acts.md#a-call-ends-with-its-run
    func abandon(_ id: Int?) {
        guard let id, let completion = completions.removeValue(forKey: id) else { return }
        completion(.cancelled)
        actCalls.append(ActCall(ApplicationContract.cancelCall, id))
        UIThreadExecutor.shared.askForTurn()
    }

    /// Reports a handler that threw, as an ordinary act.
    func report(_ error: Error) {
        send(ApplicationContract.handlerFailed, String(describing: error))
    }

    /// Hands the queued acts over typed; a Swift host answers each by its id.
    func takeActCalls() -> [ActCall] {
        // Saves become acts here, one per key per take with the last value.
        // Design: docs/design/core/state.md#kept-state
        let saves = PersistentStore.shared.takeWaiting().map {
            ActCall(ApplicationContract.persistValue, Name($0.name), $0.value)
        }

        let queued = actCalls
        actCalls.removeAll(keepingCapacity: true)

        // And what the open scenes keep, the same way (OpenScenes.swift).
        return queued + saves + OpenScenes.shared.takeSaves()
    }
}

/// The id a waiting caller's answer comes under: written as the call is queued and read as its run is cancelled.
private final class WaitingCall: Sendable {
    let id = Mutex<Int?>(nil)
}
