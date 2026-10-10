// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The runs under way through one gate: what an event that comes while one is under way does, by the gate's policy.
/// Design: docs/design/core/runs.md#a-gate
@MainActor
final class RunSlot {
    /// One run the slot took: under way, or waiting for its turn while `turn` is set.
    private final class Entry {
        let run = HandlerRun()
        let owner: ObjectIdentifier
        var task: Task<Void, Never>?
        var turn: CheckedContinuation<Bool, Never>?

        init(owner: ObjectIdentifier) { self.owner = owner }
    }

    private var entries: [Entry] = []

    /// How many runs of every slot are under way or wait: what a test waits on, and the tally's `runs`.
    private(set) static var underWay = 0

    /// Told whether a run is under way or waits, as that changes.
    var busyChanged: ((Bool) -> Void)?

    private var busy = false {
        didSet { if busy != oldValue { busyChanged?(busy) } }
    }

    /// Starts `handler` for `owner` as `policy` says, given the runs under way: the run's task, ended at once where
    /// the policy lets it go.
    @discardableResult
    func start(
        _ handler: @escaping EventHandler, _ policy: GatePolicy, payload: [PropValue]?, owner: RunOwner
    ) -> Task<Void, Never> {
        owner.started(in: self)
        let entry = Entry(owner: ObjectIdentifier(owner))
        let run = entry.run

        let task = Task.immediate { @MainActor in
            guard await self.admit(entry, policy) else { return }

            if Task.isCancelled {
                run.supersede()
            } else {
                await HandlerRun.$current.withValue(run) {
                    if let payload { EventBuffer.current = payload }

                    do {
                        try await withTaskCancellationHandler {
                            try await handler()
                        } onCancel: {
                            run.supersede()
                        }
                    } catch is CancellationError where run.superseded {
                        // A superseded run ends here, as asked.
                    } catch {
                        Renderer.shared.report(error)
                    }
                }
            }

            self.finished(entry)
        }

        entry.task = task
        return task
    }

    /// `owner`'s runs are superseded and its waiting ones end unrun; the other owners' stand.
    func orphan(_ owner: RunOwner) {
        let leaving = ObjectIdentifier(owner)
        supersede { $0 == leaving }
        dropWaiting { $0.owner == leaving }
    }

    /// Whether `entry` runs, as `policy` says given the runs under way: let go, after the others, or now.
    private func admit(_ entry: Entry, _ policy: GatePolicy) async -> Bool {
        if !entries.isEmpty {
            switch policy.kind {
            case .ignoreWhileRunning:
                return false
            case .cancelPrevious:
                supersede { _ in true }
            case .waitForPrevious:
                let run = entry.run
                return await withTaskCancellationHandler {
                    await withCheckedContinuation { turn in
                        entry.turn = turn
                        take(entry)
                    }
                } onCancel: {
                    libraryTask { self.dropWaiting { $0.run === run } }
                }
            case .none:
                break
            }
        }

        take(entry)
        return true
    }

    private func take(_ entry: Entry) {
        entries.append(entry)
        RunSlot.underWay += 1
        busy = true
    }

    /// The waiting runs `chosen` picks leave the queue unrun, their tasks ending.
    private func dropWaiting(where chosen: (Entry) -> Bool) {
        let dropped = entries.filter { $0.turn != nil && chosen($0) }
        entries.removeAll { entry in dropped.contains { $0 === entry } }
        RunSlot.underWay -= dropped.count
        for entry in dropped {
            let turn = entry.turn
            entry.turn = nil
            turn?.resume(returning: false)
        }
        busy = !entries.isEmpty
    }

    private func supersede(where chosen: (ObjectIdentifier) -> Bool) {
        for entry in entries where entry.turn == nil && chosen(entry.owner) && !entry.run.superseded {
            entry.run.supersede()
            entry.task?.cancel()
        }
    }

    private func finished(_ entry: Entry) {
        entries.removeAll { $0 === entry }
        RunSlot.underWay -= 1

        if !entries.contains(where: { $0.turn == nil }), let next = entries.first {
            let turn = next.turn
            next.turn = nil
            turn?.resume(returning: true)
        }
        busy = !entries.isEmpty
    }
}

/// Who started a run: a handler of an element's event, what an element's walk found to run, a host event's
/// subscription, a shared gate's tasks, or a control the library composes. An element leaving supersedes its owners'
/// runs - in a gate others pass through too, its own alone.
/// Design: docs/design/core/runs.md#a-gate
@MainActor
final class RunOwner {
    private var slots: [RunSlot] = []

    /// The runs of a handler whose gate is a policy alone, each handler its own.
    private(set) lazy var ownRuns = RunSlot()

    /// A run of this owner started in `slot`.
    func started(in slot: RunSlot) {
        if !slots.contains(where: { $0 === slot }) { slots.append(slot) }
    }

    /// Every run this owner started is superseded, in the order its slots were first used.
    func orphan() {
        for slot in slots { slot.orphan(self) }
        slots.removeAll()
    }
}
