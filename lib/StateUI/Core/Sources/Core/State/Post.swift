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

extension StatePart where Value: Sendable {
    /// Writes `value` through the part from any thread, in a job of
    /// `MainActor`'s soon after - a post to a part waits under that part.
    ///
    /// - Parameter value: what the part holds once the job runs.
    public nonisolated func post(_ value: Value) {
        guard HandlerRun.admits("a post") else { return }

        mailroom.post(value, through: self)
    }

    /// Changes the value through the part from any thread, in a job of
    /// `MainActor`'s soon after, each change over what the one before left.
    ///
    /// - Parameter transform: given the value as it stands, answers the next.
    public nonisolated func post(_ transform: @escaping @Sendable (Value) -> Value) {
        guard HandlerRun.admits("a post") else { return }

        mailroom.post(transform, through: self)
    }
}

/// What a post writes through - a whole state's binding, or a part of one.
@MainActor
protocol PostTarget<Value>: Sendable {
    associatedtype Value

    /// Which part of the state it writes; nil for the whole.
    nonisolated var lent: PartPath? { get }

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

        /// The mailroom of the state this one's was given up for, where every post goes from then on.
        var forwarded: Mailroom?
    }

    private let waiting = Mutex(Waiting())

    /// Where each post stands in the order posted, across every mailroom.
    private static let posted = Atomic<UInt64>(0)

    /// Sends every post from now on to `other`, and what waits here with them, each step at its place in the order
    /// posted: this mailroom's state was given up for `other`'s - a view's state adopted.
    func forward(to other: Mailroom) {
        guard other !== self else { return }

        let moved = waiting.withLock { waiting in
            waiting.forwarded = other
            defer { waiting.entries = [] }
            return waiting.entries
        }
        if !moved.isEmpty { other.take(moved) }
    }

    /// Replaces whatever waits for this part, and for every part of it, with a value - posted last, it lands last.
    func post<Target: PostTarget>(_ value: Target.Value, through target: Target) where Target.Value: Sendable {
        post(value, through: target, order: Self.posted.add(1, ordering: .relaxed).newValue)
    }

    private func post<Target: PostTarget>(
        _ value: Target.Value, through target: Target, order: UInt64
    ) where Target.Value: Sendable {
        let onward = book { entries in
            entries.removeAll { PartPath.covers(target.lent, $0.part) }
            entries.append(PartPost(target: target, value: (order, value)))
        }
        onward?.post(value, through: target, order: order)
    }

    /// Queues a change after whatever waits - on the last entry where it is this part's, so a loop's changes are one
    /// write.
    func post<Target: PostTarget>(
        _ transform: @escaping @Sendable (Target.Value) -> Target.Value, through target: Target
    ) where Target.Value: Sendable {
        post(transform, through: target, order: Self.posted.add(1, ordering: .relaxed).newValue)
    }

    private func post<Target: PostTarget>(
        _ transform: @escaping @Sendable (Target.Value) -> Target.Value, through target: Target, order: UInt64
    ) where Target.Value: Sendable {
        let onward = book { entries in
            if var last = entries.last as? PartPost<Target>, last.part == target.lent {
                last.transforms.append((order, transform))
                entries[entries.count - 1] = last
            } else {
                entries.append(PartPost(target: target, transforms: [(order, transform)]))
            }
        }
        onward?.post(transform, through: target, order: order)
    }

    /// Records a post, and books the job where none is booked - or answers the mailroom this one's posts go to.
    private func book(_ post: (inout [any PostEntry]) -> Void) -> Mailroom? {
        let (onward, first) = waiting.withLock { waiting -> (Mailroom?, Bool) in
            if let onward = waiting.forwarded { return (onward, false) }

            post(&waiting.entries)
            defer { waiting.booked = true }
            return (nil, !waiting.booked)
        }

        if first {
            libraryTask { self.write() }
        }
        return onward
    }

    /// Takes what waited in a mailroom given up for this one: every step of every entry, in the order posted, a value
    /// replacing what waits before it for its part as a post does.
    private func take(_ moved: [any PostEntry]) {
        let (onward, first) = waiting.withLock { waiting -> (Mailroom?, Bool) in
            if let onward = waiting.forwarded { return (onward, false) }

            var merged: [any PostEntry] = []
            for step in (waiting.entries + moved).flatMap(\.steps).sorted(by: { $0.order < $1.order }) {
                if step.replaces { merged.removeAll { PartPath.covers(step.part, $0.part) } }
                merged.append(step)
            }
            waiting.entries = merged
            defer { waiting.booked = true }
            return (nil, !waiting.booked)
        }

        if let onward { return onward.take(moved) }
        if first {
            libraryTask { self.write() }
        }
    }

    /// The job: what waits, taken whole and written entry by entry in the order posted.
    @MainActor
    private func write() {
        let taken = waiting.withLock { waiting in
            defer { (waiting.entries, waiting.booked) = ([], false) }
            return waiting.entries
        }

        for entry in taken { entry.land() }
    }
}

/// One part's posts waiting in a mailroom.
protocol PostEntry: Sendable {
    /// Which part of the state it writes; nil for the whole.
    var part: PartPath? { get }

    /// Where its first step stands in the order posted.
    var order: UInt64 { get }

    /// Whether its first step is a value, which replaces what waited before it for its part.
    var replaces: Bool { get }

    /// Each of its steps as an entry of its own, in order.
    var steps: [any PostEntry] { get }

    /// Writes what waits.
    @MainActor func land()
}

/// What waits for one part: the last value posted and the changes posted after it, in order, each with its place in
/// the order posted, written through a binding or that part - held only until the job runs.
struct PartPost<Target: PostTarget>: PostEntry where Target.Value: Sendable {
    let target: Target
    var value: (order: UInt64, value: Target.Value)?
    var transforms: [(order: UInt64, change: @Sendable (Target.Value) -> Target.Value)] = []

    var part: PartPath? { target.lent }

    var order: UInt64 { value?.order ?? transforms.first?.order ?? 0 }

    var replaces: Bool { value != nil }

    var steps: [any PostEntry] {
        (value.map { [PartPost(target: target, value: $0)] } ?? [])
            + transforms.map { PartPost(target: target, transforms: [$0]) }
    }

    init(
        target: Target, value: (order: UInt64, value: Target.Value)? = nil,
        transforms: [(order: UInt64, change: @Sendable (Target.Value) -> Target.Value)] = []
    ) {
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

        var landing = value?.value ?? target.standing

        for transform in transforms {
            landing = transform.change(landing)
        }

        target.wrappedValue = landing
    }
}
