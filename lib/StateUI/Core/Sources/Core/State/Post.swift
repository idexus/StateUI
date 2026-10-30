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
    ///     let results = $results
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
        guard HandlerRun.admits("a post") else { return }

        mailroom.post(value, through: self)
    }

    /// Changes the state from any thread, in a job of `MainActor`'s soon after:
    /// every change posted runs in the order posted, each over what the one
    /// before left - so many tasks counting at once all count.
    ///
    ///     let done = $done
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
        guard HandlerRun.admits("a post") else { return }

        mailroom.post(transform, through: self)
    }
}

extension Binding.Proxy where Value: Sendable {
    /// Writes `value` through the proxy from any thread, in a job of
    /// `MainActor`'s soon after - a post to a part waits under that part.
    ///
    /// - Parameter value: what the part holds once the job runs.
    public nonisolated func post(_ value: Value) {
        guard HandlerRun.admits("a post") else { return }

        mailroom.post(value, through: self)
    }

    /// Changes the value through the proxy from any thread, in a job of
    /// `MainActor`'s soon after, each change over what the one before left.
    ///
    /// - Parameter transform: given the value as it stands, answers the next.
    public nonisolated func post(_ transform: @escaping @Sendable (Value) -> Value) {
        guard HandlerRun.admits("a post") else { return }

        mailroom.post(transform, through: self)
    }
}

/// What a post writes through - a whole state's binding, or a proxy to a part of one.
@MainActor
protocol PostTarget<Value>: Sendable {
    associatedtype Value

    /// Which part of the state it writes; nil for the whole.
    nonisolated var lent: StatePart? { get }

    /// The value as it stands, without recording a read.
    var standing: Value { get }

    /// Whether what it writes still stands.
    func reaches() -> Bool

    var wrappedValue: Value { get nonmutating set }
}


/// What has been posted to one state and not yet written, in the order posted - each entry a part of the state and
/// what waits for it - written by one job of `MainActor`'s.
/// Design: docs/design/core/state.md#posting
final class Mailroom: Sendable {
    private struct Waiting {
        var entries: [any PostEntry] = []
        var booked = false
    }

    private let waiting = Mutex(Waiting())

    /// Replaces whatever waits for this part, and for every part of it, with a value - posted last, it lands last.
    func post<Target: PostTarget>(_ value: Target.Value, through target: Target) where Target.Value: Sendable {
        book { entries in
            entries.removeAll { StatePart.covers(target.lent, $0.part) }
            entries.append(PartPost(target: target, value: value))
        }
    }

    /// Queues a change after whatever waits - on the last entry where it is this part's, so a loop's changes are one
    /// write.
    func post<Target: PostTarget>(
        _ transform: @escaping @Sendable (Target.Value) -> Target.Value, through target: Target
    ) where Target.Value: Sendable {
        book { entries in
            if var last = entries.last as? PartPost<Target>, last.part == target.lent {
                last.transforms.append(transform)
                entries[entries.count - 1] = last
            } else {
                entries.append(PartPost(target: target, transforms: [transform]))
            }
        }
    }

    /// Records a post, and books the job where none is booked.
    private func book(_ post: (inout [any PostEntry]) -> Void) {
        let first = waiting.withLock { waiting in
            post(&waiting.entries)
            defer { waiting.booked = true }
            return !waiting.booked
        }

        if first {
            libraryTask { self.write() }
        }
    }

    /// The job: what waits, taken whole and written entry by entry in the order posted.
    @MainActor
    private func write() {
        let taken = waiting.withLock { waiting in
            defer { waiting = Waiting() }
            return waiting.entries
        }

        for entry in taken { entry.land() }
    }
}

/// One part's posts waiting in a mailroom.
protocol PostEntry: Sendable {
    /// Which part of the state it writes; nil for the whole.
    var part: StatePart? { get }

    /// Writes what waits.
    @MainActor func land()
}

/// What waits for one part: the last value posted and the changes posted after it, in order, written through a
/// binding or a proxy to that part - held only until the job runs.
struct PartPost<Target: PostTarget>: PostEntry where Target.Value: Sendable {
    let target: Target
    var value: Target.Value?
    var transforms: [@Sendable (Target.Value) -> Target.Value] = []

    var part: StatePart? { target.lent }

    init(target: Target, value: Target.Value? = nil, transforms: [@Sendable (Target.Value) -> Target.Value] = []) {
        self.target = target
        self.value = value
        self.transforms = transforms
    }

    @MainActor
    func land() {
        guard target.reaches() else {
            return complain("A post to an element its collection no longer has - the list shrank before the post's "
                + "job ran - was dropped. Post by the element's identity rather than its index.")
        }

        var landing = value ?? target.standing

        for transform in transforms {
            landing = transform(landing)
        }

        target.wrappedValue = landing
    }
}
