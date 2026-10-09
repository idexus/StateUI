// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// One run of a handler, which a later event or its element leaving can supersede; the run's task and every
/// task under it read it as `HandlerRun.current`.
/// Design: docs/design/core/runs.md#a-superseded-run
final class HandlerRun: Sendable {
    /// The run the calling task belongs to; nil outside every handler.
    @TaskLocal static var current: HandlerRun?

    /// Superseded runs still under way: a write reads this alone while there are none.
    private static let supersededUnderWay = Atomic<Int>(0)

    private let isSuperseded = Atomic<Bool>(false)

    #if DEBUG
    /// The stamp of each state this run read, as it stood at the read.
    private let read = Mutex<[ObjectIdentifier: Int]>([:])

    /// Notes what `state` stood at as the current run read it.
    @MainActor static func noteRead(of state: AnyObject) {
        guard let run = current, let stamp = (state as? any FollowedState)?.stamp else { return }

        run.read.withLock { $0[ObjectIdentifier(state)] = stamp }
    }

    /// Says where the current run writes `state` on what it read of it before another wrote it - across an
    /// `await` - a write built on a value gone.
    /// Design: docs/design/core/runs.md#a-write-built-on-a-value-gone
    @MainActor static func noteWrite(of state: AnyObject, named name: @autoclosure () -> String) {
        guard let run = current, let stamp = (state as? any FollowedState)?.stamp,
              let stood = run.read.withLock({ $0.removeValue(forKey: ObjectIdentifier(state)) }),
              stood != stamp
        else { return }

        complain("\(name()) was written by a handler that read it before an `await`, and it changed while the "
            + "handler waited: the write is built on what it was. Read it again after the `await`.")
    }
    #endif

    var superseded: Bool { isSuperseded.load(ordering: .relaxed) }

    /// Marks the run superseded: from now on it changes nothing.
    func supersede() {
        guard !isSuperseded.exchange(true, ordering: .relaxed) else { return }

        Self.supersededUnderWay.add(1, ordering: .relaxed)
    }

    func ended() {
        if superseded { Self.supersededUnderWay.subtract(1, ordering: .relaxed) }
    }

    /// Whether the calling task may change something: false in a superseded run, said once where `what` names it.
    /// Design: docs/design/core/runs.md#a-superseded-run
    static func admits(_ what: @autoclosure () -> String) -> Bool {
        guard supersededUnderWay.load(ordering: .relaxed) > 0, let run = current, run.superseded else { return true }

        complain("\(what()) came from a run of a handler that a later event, or its element leaving, superseded; "
            + "it was refused. A run that awaits changes nothing once superseded.")
        return false
    }
}
