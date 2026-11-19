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

/// The display cycle's images, engines and cycle.
/// Design: docs/design/core/cycle.md#the-board
@MainActor
final class CycleBoard {
    /// Every storage of this board, weakly: a state belongs to its view.
    private var storages: [WeakStorage] = []

    /// The engines in running order: ascending priority, then registration.
    private var engines: [EngineEntry] = []

    /// The conversions live elements wear, kept up to date from their sources' destinations.
    /// Design: docs/design/core/journeys.md#the-graph-of-destinations
    let conversions = ConversionGraph()

    /// The movements engines finished this cycle, for the host to answer once it has shown the frame.
    /// Design: docs/design/core/journeys.md#an-engine-that-animates
    var finished: [HostFinishedMotion] = []

    /// The layouts whose program was worked out this cycle, for the host to read once the cycle is over.
    /// Design: docs/design/core/layout-program.md#what-runs-it-again
    var stirred: [UInt64] = []

    /// The samples the animators offered this cycle, published together once they have all run.
    private var offered: [() -> Void] = []

    /// Offers a sample an animator made, published with the others of its cycle.
    func offer(_ publish: @escaping () -> Void) {
        if cycling { offered.append(publish) } else { publish() }
    }

    /// The readings booked for the end of their window, known weakly, in the order booked.
    /// Design: docs/design/core/journeys.md#readings
    private var readings: [WeakSampling] = []

    /// Books `sampling` for the first frame at or past the end of its window: the clock is held until then.
    func book(_ sampling: Sampling) {
        readings.append(WeakSampling(sampling))
    }

    /// Whether a cycle is between its latch and its publish - which decides where a
    /// write lands and what a read answers.
    /// Design: docs/design/core/cycle.md#three-copies-of-a-value
    private var cycling = false

    /// When the last cycle ran, on the clock the host hands in.
    private var last: Double = 0

    /// How many cycles have run.
    private var count: UInt64 = 0

    /// The time of the display's latest frame this side heard of - a report's or a cycle's - which every sample
    /// read until the next one shares.
    /// Design: docs/design/core/journeys.md#the-sample
    private(set) var frameTime: Double = 0

    /// The display's frame at `time` has begun; time never goes back.
    func frame(at time: Double) {
        frameTime = max(frameTime, time)
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
        storage.targetRevision &+= 1
    }

    /// A storage's image, what of it waits to be published and its counts, as they stand.
    struct Held {
        let image: [UInt8]
        let pending: [UInt8]?
        let pendingMask: UInt64
        let dirty: UInt64
        let stamp: Int
        let targetRevision: Int
    }

    /// What `storage` holds now, for `restore` to put back.
    func held(_ storage: HostStorage) -> Held {
        Held(
            image: storage.image, pending: storage.pending, pendingMask: storage.pendingMask, dirty: storage.dirty,
            stamp: storage.stamp, targetRevision: storage.targetRevision)
    }

    /// Puts `storage` back as `held` had it - its image, what waited to be published then and its counts, no
    /// more: writes taken back publish nothing and wake nobody, and what waited before them still does.
    /// Design: docs/design/core/journeys.md#the-way-back
    func restore(_ held: Held, to storage: HostStorage) {
        (storage.image, storage.pending) = (held.image, held.pending)
        (storage.pendingMask, storage.dirty) = (held.pendingMask, held.dirty)
        (storage.stamp, storage.targetRevision) = (held.stamp, held.targetRevision)
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
    /// pending slot between cycles. `forcing` marks lanes a write means even where the
    /// bytes did not move; `stamping` says the write is one of the state's value - the
    /// destination, on a journey's image - which moves the stamp, equal bytes included.
    /// Design: docs/design/core/cycle.md#where-a-write-lands
    func write(_ bytes: [UInt8], to storage: HostStorage, forcing forced: UInt64 = 0, stamping: Bool = true) {
        if stamping { storage.stamp &+= 1 }

        if cycling {
            let moved = HostStorage.lay(bytes, into: &storage.image)
            storage.dirty |= moved | forced
            if moved & storage.targetMask != 0 { storage.targetRevision &+= 1 }
            return
        }

        var slot = storage.pending ?? storage.image
        let moved = HostStorage.lay(bytes, into: &slot)

        storage.pendingMask |= moved | forced
        storage.pending = slot
        if moved & storage.targetMask != 0 { storage.targetRevision &+= 1 }

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
        var moved: UInt64 = 0

        func lay(into slot: inout [UInt8]) {
            moved = laid == ~0
                ? HostStorage.lay(bytes, into: &slot)
                : HostStorage.lay(bytes, into: &slot, only: laid)
        }

        if laid != 0 { storage.reports &+= 1 }

        if cycling {
            lay(into: &storage.image)
            storage.dirty &= ~laid
        } else {
            var slot = storage.pending ?? storage.image

            lay(into: &slot)
            storage.pending = slot
            storage.pendingMask &= ~laid
            storage.dirty &= ~laid
        }

        // A journey's frame - where it stands, how fast - is no write of the state: its destination moved is one.
        // Design: docs/design/core/cycle.md#what-wakes-an-engine
        if storage.journeyWidth == nil || moved & storage.destinationMask != 0 { storage.stamp &+= 1 }
        if moved & storage.targetMask != 0 { storage.targetRevision &+= 1 }
        return laid
    }

    /// Every state with lanes waiting, in ascending order, with what each holds - the
    /// per-frame read. The bits answered are cleared.
    /// Design: docs/design/core/cycle.md#the-per-frame-read
    func dirty() -> [(number: Int32, mask: UInt64, bytes: [UInt8])] {
        var answered: [(number: Int32, mask: UInt64, bytes: [UInt8])] = []

        for held in storages {
            guard let storage = held.storage, storage.dirty != 0 else { continue }

            // A state with no number has no reader; a registration later reads it whole.
            if let number = storage.number {
                answered.append((number, storage.dirty, storage.crossing()))
            }

            storage.dirty = 0
        }

        return answered.sorted { $0.number < $1.number }
    }

    /// One state whole, nothing cleared - what a registration reads; nil where no
    /// state rides that number.
    func whole(_ number: Int32) -> [UInt8]? {
        storages.first { $0.storage?.number == number }?.storage?.crossing()
    }

    /// Registers an engine, which runs from the next cycle. One entry a number: an entry the board still holds
    /// under it - a differ begun afresh numbers from one again - gives way, with what it claimed.
    /// Design: docs/design/core/cycle.md#the-board
    func arm(_ entry: EngineEntry) {
        disarm(entry.id)
        engines.append(entry)
        order()
    }

    /// The engines in the order they run: ascending priority, ties by id.
    private func order() {
        engines.sort { ($0.priority, $0.id) < ($1.priority, $1.id) }
    }

    /// Forgets an engine - the view that declared it has gone - and lets go of what it claimed.
    func disarm(_ id: Int) {
        let released = engines.first { $0.id == id }?.released
        engines.removeAll { $0.id == id }
        released?()
    }

    /// Hands an engine a fresh render's closure, priority and followed states, and arms it - moved in the order
    /// where its priority changed. Answers whether there was one to hand it to.
    @discardableResult
    func rearm(
        _ id: Int,
        priority: Double,
        following follows: [any FollowedState],
        with run: @escaping @MainActor (EngineCycle) -> EngineAnswer
    ) -> Bool {
        guard let place = place(of: id) else { return false }

        engines[place].run = run
        engines[place].follow(follows)
        engines[place].armed = true
        if engines[place].priority != priority {
            engines[place].priority = priority
            order()
        }
        return true
    }

    /// Whether this board holds an engine under that number - what a test asks.
    func holds(_ id: Int) -> Bool {
        place(of: id) != nil
    }

    /// Whether anything at all is waiting for a cycle.
    var awake: Bool {
        stirring || written || conversions.isStale || readings.contains { $0.sampling?.booked != nil }
    }

    /// Whether anything waits that a turn answers at once: a write latched or to be, an engine armed or a state it
    /// follows written. An engine going on of its own waits for the display's frame.
    /// Design: docs/design/core/cycle.md#what-wakes-an-engine
    var asked: Bool {
        written || conversions.isStale || engines.contains { $0.asked }
    }

    /// Whether a write waits: one to latch, or one latched the host has not read.
    private var written: Bool {
        storages.contains { $0.storage?.pending != nil || ($0.storage?.dirty ?? 0) != 0 }
    }

    /// One cycle: what was written latched, the engines with a reason run, and what
    /// they wrote published. A first cycle, or one after a long silence, tells them nought.
    /// Design: docs/design/core/cycle.md#a-start-is-a-gap
    @discardableResult
    func cycle(now instant: Double, reducesMotion: Bool) -> CycleReport {
        var report = CycleReport()
        let now = max(last, instant)
        frame(at: now)
        let started = count == 0 || now - last > EngineCycle.mostElapsedMilliseconds

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

        // The destinations written since, carried to what is derived from them, before anything reads them.
        // Design: docs/design/core/journeys.md#the-graph-of-destinations
        conversions.settle()

        // The readings whose window ended take what stands, before the engines read their targets.
        readings.removeAll { $0.sampling?.takeBooked(at: now) ?? true }

        // A start moves every engine's clock to now: one with a reason runs, told nought.
        if started {
            for place in engines.indices { engines[place].lastRan = now }
        }

        // The animators first, each on what the frame before left, their samples published together; then every
        // other engine, asked for its reason just before its turn, so a write an earlier one made wakes it in the
        // same cycle.
        // Design: docs/design/core/cycle.md#engine-order
        let animators = engines.filter(\.animates).map(\.id)
        let others = engines.filter { !$0.animates }.map(\.id)
        for id in animators + [Self.published] + others {
            if id == Self.published {
                let publish = offered
                offered = []
                publish.forEach { $0() }
                continue
            }
            guard let place = place(of: id), engines[place].due else {
                report.skipped += 1
                continue
            }

            // Taken out first: the engine may arm or disarm others as it runs.
            let (run, lastRan) = (engines[place].run, engines[place].lastRan)
            let elapsed = min(max(now - lastRan, 0), EngineCycle.mostElapsedMilliseconds)
            let answer = run(EngineCycle(
                now: now,
                elapsed: elapsed,
                count: count,
                reducesMotion: reducesMotion))

            // The engine may have taken its view, and itself, away.
            // Design: docs/design/core/cycle.md#what-wakes-an-engine
            self.place(of: id).map { engines[$0].ran(at: now, answering: answer) }

            report.ran += 1
        }

        // And what the engines wrote, before it is published.
        conversions.settle()

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

        return report
    }

    /// The place in a cycle's order where the animators' samples are published: no engine's number.
    private static let published = Int.min

    /// A clock of its own: the board's time starts over on it, and its next cycle is a start.
    func restartClock() {
        last = 0
        count = 0
        frameTime = 0
    }

    /// Forgets everything - a fresh process's board, for a test.
    func clear() {
        storages = []
        engines = []
        readings = []
        finished = []
        offered = []
        conversions.clear()
        cycling = false
        last = 0
        count = 0
        frameTime = 0
    }

    /// Whether any engine has a reason to run, so the clock is not let go with work
    /// piled up.
    private var stirring: Bool { engines.contains { $0.due } }

    /// Where the engine registered under `id` stands in the running order.
    private func place(of id: Int) -> Int? { engines.firstIndex { $0.id == id } }

    /// A storage this board holds, weakly.
    private struct WeakStorage {
        weak var storage: HostStorage?
    }
}
