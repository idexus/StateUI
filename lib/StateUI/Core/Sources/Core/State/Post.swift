// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The one door into a state from outside `MainActor`: what is posted waits in the
// state's mailroom for one job on `MainActor`, which writes it.
// Design: docs/design/core/state.md#posting

import Synchronization

extension Binding where Value: Sendable {
    /// Writes `value` into the state from any thread, in a job of `MainActor`'s
    /// soon after - never at once, even on the UI thread. Of values posted before
    /// the job runs, the last one stands.
    ///
    ///     Task.detached {
    ///         let found = await search(query)
    ///         results.post(found)
    ///     }
    ///
    /// On `MainActor`, write the state: `results = found`.
    ///
    /// - Parameter value: what the state holds once the job runs.
    public nonisolated func post(_ value: Value) {
        slot.post(value)
    }

    /// Changes the state from any thread, in a job of `MainActor`'s soon after:
    /// every change posted runs in the order posted, each over what the one
    /// before left - so many tasks counting at once all count.
    ///
    ///     await withTaskGroup(of: Void.self) { group in
    ///         for chunk in chunks {
    ///             group.addTask { done.post { $0 + chunk.count } }
    ///         }
    ///     }
    ///
    /// A value posted afterwards replaces the changes waiting before it.
    ///
    /// - Parameter transform: given the value as it stands, answers the next.
    public nonisolated func post(_ transform: @escaping @Sendable (Value) -> Value) {
        slot.post(transform)
    }

    /// Where this part of the state waits for its job.
    private nonisolated var slot: PostSlot<Value> {
        mailroom.slot(lent, of: self)
    }
}

/// What has been posted to one state and not yet written: a slot for each part of
/// it something was posted to.
/// Design: docs/design/core/state.md#posting
final class Mailroom: Sendable {
    private let slots = Mutex<[AnyHashable?: AnyObject]>([:])

    /// The slot of one part of the state, made the first time anything is posted to
    /// it.
    func slot<Value: Sendable>(_ part: (any Hashable & Sendable)?, of binding: Binding<Value>) -> PostSlot<Value> {
        slots.withLock { slots in
            let key = part.map { AnyHashable($0) }

            if let standing = slots[key] as? PostSlot<Value> { return standing }

            let made = PostSlot(binding)

            slots[key] = made
            return made
        }
    }
}

/// What waits for one part of one state: the last value posted, and the changes
/// posted after it, in order - written by one job of `MainActor`'s.
final class PostSlot<Value: Sendable>: Sendable {
    private struct Waiting {
        var value: Value?
        var transforms: [@Sendable (Value) -> Value] = []
        var booked = false
    }

    private let waiting = Mutex(Waiting())

    /// Where the job writes - any binding to this part, each the same road.
    private let binding: Binding<Value>

    init(_ binding: Binding<Value>) {
        self.binding = binding
    }

    /// Replaces whatever waits with a value.
    func post(_ value: Value) {
        book {
            $0.value = value
            $0.transforms.removeAll()
        }
    }

    /// Queues a change after whatever waits.
    func post(_ transform: @escaping @Sendable (Value) -> Value) {
        book { $0.transforms.append(transform) }
    }

    /// Records a post, and books the job where none is booked.
    private func book(_ post: (inout Waiting) -> Void) {
        let first = waiting.withLock { waiting in
            post(&waiting)
            defer { waiting.booked = true }
            return !waiting.booked
        }

        if first {
            Task { @MainActor in self.write() }
        }
    }

    /// The job: what waits, taken whole and written once.
    @MainActor
    private func write() {
        let taken = waiting.withLock { waiting in
            defer { waiting = Waiting() }
            return waiting
        }

        var value = taken.value ?? binding.standing

        for transform in taken.transforms {
            value = transform(value)
        }

        binding.wrappedValue = value
    }
}
