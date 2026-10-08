// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// The lock state several threads touch stands behind, the state beside it.
/// Design: docs/design/core/concurrency.md#the-lock
@usableFromInline
struct Lock: ~Copyable, Sendable {
    @usableFromInline let mutex = Mutex(())

    /// Runs `body` holding the lock; not reentrant, so what it takes out runs after.
    @inlinable
    borrowing func withLock<Result>(_ body: () -> Result) -> Result {
        mutex.withLock { _ in body() }
    }
}
