// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What an id the host reports runs: a handler, or a continuation waiting.
// Design: docs/design/core/render.md#starting-a-handler

extension Renderer {
    /// Runs what an id refers to: an element's handler, or a waiting continuation
    /// when negative. False for an unknown id, which is not an error.
    func dispatch(_ handlerId: Int) -> Bool {
        if handlerId < 0 {
            // Removed under the lock, invoked outside it: a resume may run code that takes it.
            let taken = guarded.withLock { completions.removeValue(forKey: handlerId) }

            guard let completion = taken else { return false }
            completion(ReplyBuffer.current)

            // Nothing runs here: the job a resume produces does not exist yet.
            return true
        }

        // The differ holds these: a carried element still answers for its buttons.
        guard let handler = differ.handler(handlerId) else { return false }

        start(handler)
        return true
    }

    /// Starts a dispatched event's handler - the road a test exercises too.
    func start(_ handler: @escaping EventHandler) {
        // Read now: a handler that suspends keeps the payload it started with.
        begin(handler, payload: EventBuffer.current)
    }

    /// Runs a handler a render's walk found, with no payload.
    func run(_ handler: @escaping EventHandler) {
        begin(handler, payload: nil)
    }

    /// Runs a handler on `MainActor` here and now, up to its first suspension.
    /// Design: docs/design/core/render.md#starting-a-handler
    private func begin(_ handler: @escaping EventHandler, payload: [PropValue]?) {
        let carried = CarriedHandler(run: handler)

        Task.immediate { @MainActor in
            if let payload {
                EventBuffer.current = payload
            }

            do {
                try await carried.run()
            } catch {
                Renderer.shared.report(error)
            }
        }

        stateUIRunJobs()
    }

    /// Starts a handler on `MainActor` in a later turn - for what a render found
    /// with no settle pass left.
    func queue(_ handler: @escaping EventHandler) {
        let carried = CarriedHandler(run: handler)

        Task { @MainActor in
            do {
                try await carried.run()
            } catch {
                Renderer.shared.report(error)
            }
        }
    }
}

/// Carries a handler into its `MainActor` task, the one place its sendability
/// is promised.
/// Design: docs/design/core/render.md#the-event-and-reply-buffers
private struct CarriedHandler: @unchecked Sendable {
    let run: EventHandler
}

/// The payload of the event being dispatched, in the event's declared order.
/// Design: docs/design/core/render.md#the-event-and-reply-buffers
enum EventBuffer {
    // Written and read during one dispatch, on the UI thread.
    nonisolated(unsafe) static var current: [PropValue] = []
}

/// The outcome of the act being answered, read by the continuation it resumes.
enum ReplyBuffer {
    // Written and read during one dispatch, on the UI thread.
    nonisolated(unsafe) static var current: Reply = .finished([])
}
