// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Jobs waiting for their time, in the order they come due - those due together in the order they were added: what
/// the UI thread keeps for later where no thread of its own can sleep.
/// Design: docs/design/core/concurrency.md#webassembly
struct Timetable<Job, Instant: Comparable> {
    private var entries: [(due: Instant, job: Job)] = []

    /// Keeps `job` until `due`.
    mutating func add(_ job: Job, due: Instant) {
        let index = entries.firstIndex { $0.due > due } ?? entries.endIndex
        entries.insert((due, job), at: index)
    }

    /// Takes every job due at `now`, in the order they come due.
    mutating func takeDue(at now: Instant) -> [Job] {
        let count = entries.firstIndex { $0.due > now } ?? entries.endIndex
        defer { entries.removeFirst(count) }
        return entries.prefix(count).map(\.job)
    }

    /// When the next job comes due; nil with none waiting.
    var nextDue: Instant? { entries.first?.due }

    var isEmpty: Bool { entries.isEmpty }

    var count: Int { entries.count }
}
