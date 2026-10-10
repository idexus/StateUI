// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// The application's events raised and waiting for the UI thread, in the order raised - raised from any thread,
/// as a post is: the first since the last delivery books one job of the UI thread's, which hands each to its
/// subscriptions.
/// Design: docs/design/core/acts.md#host-events
final class RaisedEvents: Sendable {
    /// The one queue of the process.
    static let shared = RaisedEvents()

    private struct Waiting {
        var events: [(name: String, values: [PropValue])] = []
        var booked = false
    }

    private let waiting = Mutex(Waiting())

    /// Queues one raise, on whatever thread raises it.
    func raise(_ name: String, _ values: [PropValue]) {
        let book = waiting.withLock { waiting in
            waiting.events.append((name, values))
            defer { waiting.booked = true }
            return !waiting.booked
        }
        guard book else { return }
        libraryTask { RaisedEvents.shared.deliver() }
    }

    /// Hands every event waiting to its subscriptions, in the order raised.
    @MainActor
    func deliver() {
        let events = waiting.withLock { waiting in
            defer {
                waiting.events = []
                waiting.booked = false
            }
            return waiting.events
        }
        for event in events { HostEvents.dispatch(event.name, event.values) }
    }
}
