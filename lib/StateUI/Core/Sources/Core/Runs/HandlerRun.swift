// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Synchronization

/// One run - of a handler, or of a task through a gate - which a later event, its task's cancellation or its element
/// leaving can supersede; the run's task and every task under it read it as `HandlerRun.current`.
/// Design: docs/design/core/runs.md#a-superseded-run
final class HandlerRun: Sendable {
    /// The run the calling task belongs to; nil outside every handler.
    @TaskLocal static var current: HandlerRun?

    /// How many runs have begun, ever: the mark a wait takes, to wait on the runs begun after it alone.
    @MainActor private(set) static var begun = 0

    /// The run's number, in the order the runs began.
    let number: Int

    /// The number of the run this one descends from - the run under way as it began, through whose task it was
    /// started - or its own where none was.
    /// Design: docs/design/core/runs.md#a-gate
    let origin: Int

    @MainActor init() {
        Self.begun += 1
        number = Self.begun
        origin = Self.current?.origin ?? number
    }

    /// Superseded runs still alive: a write reads this alone while there are none.
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

    /// A superseded run counts until no task holds it: its body may end before a task it started.
    deinit {
        if superseded { Self.supersededUnderWay.subtract(1, ordering: .relaxed) }
    }

    /// Whether the calling task may change something: false in a superseded run, said once where `what` names it.
    /// Design: docs/design/core/runs.md#a-superseded-run
    static func admits(_ what: @autoclosure () -> String) -> Bool {
        guard supersededUnderWay.load(ordering: .relaxed) > 0, let run = current, run.superseded else { return true }

        complain("\(what()) came from a run that a later event, its task's cancellation or its element leaving "
            + "superseded; it was refused. A run changes nothing once superseded: work that must outlive its element "
            + "- a save after the sheet closed - goes to a task of its own, `Task.detached { await model.save() }`.")
        return false
    }

    /// Whether a write of the state `origin` names may land (`admits`), one body for every state's value type.
    /// Design: docs/design/platforms/web/runtime.md#the-modules-size
    static func admitsWrite(of origin: String?) -> Bool {
        admits("a write of `\(origin ?? "a state")`")
    }
}

/// Starts a task of the library's own on `MainActor` - a ticker's loop, a late reading, a post's job: it belongs to no
/// handler's run, so no run being superseded refuses what it does.
/// Design: docs/design/core/runs.md#the-librarys-own-tasks
func libraryTask(_ operation: @escaping @MainActor () async -> Void) {
    HandlerRun.$current.withValue(nil) {
        Task { @MainActor in await operation() }
    }
}
