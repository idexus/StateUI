// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// State several threads touch, inside its lock: reached through `withLock` alone,
/// so nothing reads or writes it without the lock held.
/// Design: docs/design/core/concurrency.md#the-lock
final class Guarded<Value>: @unchecked Sendable {
    private let lock = Lock()
    private var value: Value

    init(_ value: Value) {
        self.value = value
    }

    /// Runs `body` over the value holding the lock; not reentrant, so what it takes out runs after.
    func withLock<Result>(_ body: (inout Value) -> Result) -> Result {
        lock.withLock { body(&value) }
    }
}
