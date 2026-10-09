// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The cycle: every write since the last one latched, the engines run over one
// picture, and what moved published - once per frame, in that order.
// Design: docs/design/core/cycle.md#the-board

/// What one cycle did, which is what the trace and the tests read.
struct CycleReport: Equatable {
    /// How many states were latched in.
    var latched = 0

    /// How many engines ran.
    var ran = 0

    /// How many were skipped because nothing they follow moved.
    var skipped = 0

    /// The states whose lanes moved, in ascending order.
    var written: [Int32] = []

    /// Whether any engine says it has more to do.
    var awake = false
}

/// One sync's images, engines and cycle.
/// Design: docs/design/core/cycle.md#the-board
@MainActor
final class CycleBoard {
    /// Which clock this board runs on.
    let sync: Sync

    /// Every storage of this board, weakly: a state belongs to its view.
    private var storages: [WeakStorage] = []

    /// The engines in running order: ascending priority, then registration.
    private var engines: [EngineEntry] = []

    /// Whether a cycle is between its latch and its publish - which decides where a
    /// write lands and what a read answers.
    /// Design: docs/design/core/cycle.md#three-copies-of-a-value
    private var cycling = false

    /// When the last cycle ran, on the clock the host hands in.
    private var last: Double = 0

    /// How many cycles have run.
    private var count: UInt64 = 0

    init(sync: Sync) {
        self.sync = sync
    }

    /// Gives a storage a new shape - a plain value a slider now animates as a
    /// journey - before the host has its number.
    func reshape(_ storage: HostStorage, to bytes: [UInt8]) {
        storage.image = bytes
        storage.published = bytes
        storage.pending = nil
        storage.pendingMask = 0
        storage.dirty = 0
        storage.stamp &+= 1
    }

    /// Takes a storage into this board's keeping.
    func hold(_ storage: HostStorage) {
        storages.removeAll { $0.storage == nil }
        storages.append(WeakStorage(storage: storage))
    }

    /// What a value stands at: the running cycle's image inside a cycle, the newest
    /// write or the last published picture outside one.
    func read(_ storage: HostStorage, lanes: Int) -> StateCarried {
        let bytes = cycling ? storage.image : (storage.pending ?? storage.published)

        return StateImage.carried(of: bytes, lanes: lanes)
    }

    /// Writes a value into the image during a cycle - an engine's write - or into the
    /// pending slot between cycles; the stamp moves either way. `forcing` marks lanes
    /// a write means even where the bytes did not move.
    /// Design: docs/design/core/cycle.md#where-a-write-lands
    func write(_ bytes: [UInt8], to storage: HostStorage, forcing forced: UInt64 = 0) {
        storage.stamp &+= 1

        if cycling {
            storage.dirty |= HostStorage.lay(bytes, into: &storage.image) | forced
            return
        }

        var slot = storage.pending ?? storage.image

        storage.pendingMask |= HostStorage.lay(bytes, into: &slot) | forced
        storage.pending = slot

        // A write waiting for a cycle asks for a turn.
        UIThreadExecutor.shared.askForTurn()
    }

    /// Takes in what the host wrote: the named lanes only, their dirty bits cleared;
    /// with `keepsUnread`, none written since the host last read it. Answers the
    /// lanes laid. A report naming every lane may change the value's length.
    /// Design: docs/design/core/cycle.md#what-the-host-reports
    @discardableResult
    func told(_ bytes: [UInt8], mask: UInt64, to storage: HostStorage, keepsUnread: Bool = false) -> UInt64 {
        let laid = keepsUnread ? mask & ~(storage.dirty | storage.pendingMask) : mask

        func lay(into slot: inout [UInt8]) {
            if laid == ~0 {
                _ = HostStorage.lay(bytes, into: &slot)
            } else {
                _ = HostStorage.lay(bytes, into: &slot, only: laid)
            }
        }

        storage.stamp &+= 1

        if cycling {
            lay(into: &storage.image)
            storage.dirty &= ~laid
            return laid
        }

        var slot = storage.pending ?? storage.image

        lay(into: &slot)
        storage.pending = slot
        storage.pendingMask &= ~laid
        storage.dirty &= ~laid
        return laid
    }

    /// Every state with lanes waiting, in ascending order, with what each holds - the
    /// per-frame read. The bits answered are cleared.
    /// Design: docs/design/core/cycle.md#the-per-frame-read
    func dirty() -> [(number: Int32, mask: UInt64, bytes: [UInt8])] {
        var answered: [(number: Int32, mask: UInt64, bytes: [UInt8])] = []

        for held in storages {
            guard let storage = held.storage, storage.dirty != 0,
                  let number = storage.number else { continue }

            answered.append((number, storage.dirty, storage.crossing()))
            storage.dirty = 0
        }

        return answered.sorted { $0.number < $1.number }
    }

    /// One state whole, nothing cleared - what a registration reads; nil where no
    /// state rides that number.
    func whole(_ number: Int32) -> [UInt8]? {
        storages.first { $0.storage?.number == number }?.storage?.crossing()
    }

    /// What the last cycle did, for the trace.
    private(set) var reported = CycleReport()

    /// Registers an engine, which runs from the next cycle.
    func arm(_ entry: EngineEntry) {
        engines.append(entry)
        engines.sort { ($0.priority, $0.id) < ($1.priority, $1.id) }
    }

    /// Forgets an engine - the view that declared it has gone.
    func disarm(_ id: Int) {
        engines.removeAll { $0.id == id }
    }

    /// Hands an engine a fresh render's closure and followed states, and arms it.
    /// Answers whether there was one to hand it to.
    @discardableResult
    func rearm(
        _ id: Int,
        following follows: [any FollowedState],
        with run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) -> Bool {
        guard let place = place(of: id) else { return false }

        engines[place].run = run
        engines[place].follow(follows)
        engines[place].armed = true
        return true
    }

    /// Whether this board holds an engine under that number - what a test asks.
    func holds(_ id: Int) -> Bool {
        place(of: id) != nil
    }

    /// Whether anything at all is waiting for a cycle.
    var awake: Bool {
        stirring || storages.contains {
            $0.storage?.pending != nil || ($0.storage?.dirty ?? 0) != 0
        }
    }

    /// One cycle: what was written latched, the engines with a reason run, and what
    /// they wrote published. A first cycle, or one after a long silence, only latches.
    /// Design: docs/design/core/cycle.md#a-start-is-a-gap
    @discardableResult
    func cycle(now instant: Double, reducesMotion: Bool) -> CycleReport {
        var report = CycleReport()
        let now = max(last, instant)
        let started = count == 0 || now - last > EngineCycle.mostElapsed

        count &+= 1
        cycling = true

        for held in storages {
            guard let storage = held.storage, let pending = storage.pending else { continue }

            storage.image = pending
            storage.dirty |= storage.pendingMask
            storage.pending = nil
            storage.pendingMask = 0
            report.latched += 1
        }

        // A start moves every engine's clock to now, without noting where values stand.
        if started {
            for place in engines.indices { engines[place].lastRan = now }
        }

        // Each engine is asked for its reason just before its turn, so a write an earlier one
        // made wakes it in the same cycle.
        for id in started ? [] : engines.map(\.id) {
            guard let place = place(of: id), engines[place].due else {
                report.skipped += 1
                continue
            }

            // Taken out first: the engine may arm or disarm others as it runs.
            let (run, lastRan) = (engines[place].run, engines[place].lastRan)
            let elapsed = min(max(now - lastRan, 0), EngineCycle.mostElapsed)
            let answer = run(EngineCycle(
                sync: sync,
                now: now,
                elapsed: elapsed,
                count: count,
                reducesMotion: reducesMotion))

            // The engine may have taken its view, and itself, away.
            // Design: docs/design/core/cycle.md#what-wakes-an-engine
            self.place(of: id).map { engines[$0].ran(at: now, answering: answer) }

            report.ran += 1
        }

        for held in storages {
            guard let storage = held.storage else { continue }

            storage.published = storage.image

            if storage.dirty != 0, let number = storage.number {
                report.written.append(number)
            }
        }

        cycling = false
        report.awake = stirring
        report.written.sort()
        last = now
        reported = report

        return report
    }

    /// Forgets everything - a fresh process's board, for a test.
    func clear() {
        storages = []
        engines = []
        cycling = false
        last = 0
        count = 0
    }

    /// Whether any engine has a reason to run. A latching cycle counts it too, so the
    /// clock is not let go with work piled up.
    private var stirring: Bool { engines.contains { $0.due } }

    /// Where the engine registered under `id` stands in the running order.
    private func place(of id: Int) -> Int? { engines.firstIndex { $0.id == id } }

    /// A storage this board holds, weakly.
    private struct WeakStorage {
        weak var storage: HostStorage?
    }
}
