// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// The lock state that more than one thread touches stands behind.
///
/// A handler writes a `@State` on the UI thread while a task writes it from the
/// pool and the host renders; an act is queued from a child task while the
/// host takes the queue. Everything a class keeps for that - a storage's
/// value, the renderer's registries, a board's images - is read and written
/// only inside `withLock`, with the state beside the lock rather than in it.
///
/// Beside, because what it guards is often no value a lock could hold: a
/// `@State`'s value is whatever type its author declares, `Sendable` or not,
/// and a value handed into a `Mutex<Value>` has to be `sending`, which a
/// property setter cannot promise. So the lock is a `Mutex` guarding nothing,
/// and a hold costs what an uncontended `Mutex` costs - a few nanoseconds.
///
/// Not reentrant: a body that asks for the same lock again deadlocks. What a
/// body takes out - a continuation to resume, a handler to call - is invoked
/// after `withLock` returns.
struct Lock: ~Copyable, Sendable {
    private let mutex = Mutex(())

    /// Runs `body` holding the lock and answers what it returned.
    ///
    /// - Parameter body: what reads and writes the guarded state.
    /// - Returns: what `body` returned.
    borrowing func withLock<Result>(_ body: () -> Result) -> Result {
        mutex.withLock { _ in body() }
    }
}
