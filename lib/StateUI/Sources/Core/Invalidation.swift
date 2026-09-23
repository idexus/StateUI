// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Which state was read where: the half of invalidation the differ cannot see.
// The other half, which state was written, is `Renderer.stateChanged`.
// Design: docs/design/core/invalidation.md#two-facts

import Synchronization

/// The read scopes open now, innermost last: one around each build the differ
/// runs, and one around the root build.
/// Design: docs/design/core/invalidation.md#the-reader-is-the-closure-that-read
enum ReadScope {
    /// Guards the stack: a read may arrive from a pool thread.
    private static let guarded = Lock()

    private nonisolated(unsafe) static var stack: [Set<ObjectIdentifier>] = []

    /// How many scopes are open, kept beside the stack for the fast path below.
    private static let depth = Atomic<Int>(0)

    /// Records a read into the innermost open scope, answering whether one was open.
    /// The empty check is a relaxed atomic load, since every read lands here.
    /// Design: docs/design/core/invalidation.md#reads-from-other-threads
    @discardableResult
    static func note(_ id: ObjectIdentifier) -> Bool {
        guard depth.load(ordering: .relaxed) > 0 else { return false }

        return guarded.withLock {
            guard !stack.isEmpty else { return false }

            stack[stack.count - 1].insert(id)
            return true
        }
    }

    /// Runs a build with a scope of its own open, and returns what it read.
    static func collect<T>(_ build: () -> T) -> (value: T, reads: Set<ObjectIdentifier>) {
        guarded.withLock {
            stack.append([])
            depth.add(1, ordering: .relaxed)
        }

        let value = build()

        let reads = guarded.withLock { () -> Set<ObjectIdentifier> in
            depth.subtract(1, ordering: .relaxed)
            return stack.removeLast()
        }

        return (value, reads)
    }

    /// The same, accumulating into a set the caller keeps across nested placeholders.
    static func collect<T>(
        into reads: inout Set<ObjectIdentifier>,
        _ build: () -> T
    ) -> T {
        let (value, found) = collect(build)
        reads.formUnion(found)
        return value
    }
}
