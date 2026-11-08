// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What an id the host reports runs: a handler, or a continuation waiting.
// Design: docs/design/core/render.md#starting-a-handler

extension Renderer {
    /// Runs what an id refers to - an element's handlers, or a waiting continuation when negative; false if unknown.
    func dispatch(_ handlerId: Int) -> Bool {
        if handlerId < 0 {
            // Removed before it runs: what it resumes may book or answer another.
            let taken = completions.removeValue(forKey: handlerId)

            guard let completion = taken else { return false }
            completion(ReplyBuffer.current)

            // Nothing runs here: the job a resume produces does not exist yet.
            return true
        }

        // The differ holds these: a carried element still answers for its buttons.
        guard let registration = differ.handler(handlerId) else { return false }

        differ.heard(handlerId)
        start(registration)
        return true
    }

    /// Starts a dispatched event's handlers, each through its gate - the road a test exercises too - outside
    /// every run: whatever task the host reported it from, its runs descend from none.
    /// Design: docs/design/core/runs.md#the-runs-of-a-handler
    func start(_ registration: EventRegistration) {
        // Read now: a handler that suspends keeps the payload it started with.
        let payload = EventBuffer.current
        HostTeardown.$current.withValue(nil) {
            HandlerRun.$current.withValue(nil) { registration.start(payload: payload) }
        }
    }

    /// Runs a handler a render's walk found, with no payload, through its gate, outside every run, as an event's.
    /// Design: docs/design/core/runs.md#what-a-walk-runs
    func run(_ fired: Fired, teardown: HostTeardown? = nil) {
        guard fired.owner?.isCurrent != false else { return }
        HostTeardown.$current.withValue(teardown) {
            HandlerRun.$current.withValue(nil) {
                if let owner = fired.owner {
                    fired.gate.runs(for: owner).start(fired.run, fired.gate.policy, payload: nil, owner: owner)
                } else {
                    begin(fired.run, payload: nil)
                }
            }
        }
    }

    /// Runs a handler on `MainActor` here and now, up to its first suspension.
    /// Design: docs/design/core/render.md#starting-a-handler
    private func begin(_ handler: @escaping EventHandler, payload: [PropValue]?) {
        let task = Task.immediate { @MainActor in
            if let payload {
                EventBuffer.current = payload
            }

            do {
                try await handler()
            } catch {
                Renderer.shared.report(error)
            }
        }
        HostTeardown.record(task)
    }

    /// Starts what a render found with no settle pass left, in a later turn of `MainActor`.
    func queue(_ fired: Fired) {
        libraryTask {
            Renderer.shared.run(fired)
        }
    }
}

/// The payload of the event being dispatched, in the event's declared order.
/// Design: docs/design/core/render.md#the-event-and-reply-buffers
@MainActor
enum EventBuffer {
    // Written and read during one dispatch, on the UI thread.
    static var current: [PropValue] = []
}

/// The outcome of the act being answered, read by the continuation it resumes.
@MainActor
enum ReplyBuffer {
    // Written and read during one dispatch, on the UI thread.
    static var current: Reply = .finished([])
}
