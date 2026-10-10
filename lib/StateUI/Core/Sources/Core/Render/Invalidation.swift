// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Which state was read where: the half of invalidation the differ cannot see.
// The other half, which state was written, is `Renderer.stateChanged`.
// Design: docs/design/core/invalidation.md#two-facts

/// The read scopes open now, innermost last: one around each build the differ
/// runs, and one around the root build.
/// Design: docs/design/core/invalidation.md#the-reader-is-the-closure-that-read
@MainActor
enum ReadScope {
    private static var stack: [Set<ObjectIdentifier>] = []

    /// Records a read into the innermost open scope, answering whether one was open.
    @discardableResult
    static func note(_ id: ObjectIdentifier) -> Bool {
        guard !stack.isEmpty else { return false }

        stack[stack.count - 1].insert(id)
        return true
    }

    /// Runs a build with a scope of its own open, and returns what it read.
    static func collect<T>(_ build: () -> T) -> (value: T, reads: Set<ObjectIdentifier>) {
        stack.append([])

        let value = build()

        return (value, stack.removeLast())
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
