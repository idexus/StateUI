// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// THE CYCLE: read, work out, write - once per frame, in that order.
//
// The shape a programmable controller has had for fifty years, and for the
// same reason: everything a cycle reads is LATCHED before any arithmetic runs,
// so every engine in one cycle sees one picture of the world, and everything
// they wrote is published together at the end. A value that changes half way
// through cannot make two engines disagree about it, and running the same
// cycle twice over the same image answers the same bytes.
//
//   (1) READ      every write made since the last cycle is taken in at once.
//   (2) WORK OUT  the engines run, in a stated order, each told how long it is
//                 since IT last ran. What one of those is: `Core/Engine.swift`.
//   (3) WRITE     what moved is published, and the host reads it out.
//
// The board is what holds one such cycle: an image, its engines, and one hold
// over both. There is one per SYNC - one clock, one cycle - and today the only
// sync is the display's own frame.

// The hold is a serial queue for the reason `Core/State.swift` gives: libdispatch
// is on every platform this targets, and Foundation's locks bring ICU on Windows.
import Dispatch

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

/// One sync's image, engines and cycle.
///
/// THE HOLD IS THE BOARD'S and every touch of a value goes through it, so a
/// write from a handler, a report from the host and an engine's own arithmetic
/// cannot tear one another. It is never held while an engine RUNS: an engine
/// reads and writes states, and a lock held across the call would be a lock the
/// engine asks for again.
final class CycleBoard: @unchecked Sendable {
    /// Which clock this board runs on.
    let sync: Sync

    private let guarded = DispatchQueue(label: "StateUI.HostState")

    /// Every storage that belongs to this board, weakly: a state is the view's,
    /// and one nobody holds any more is one nothing can write.
    private var storages: [WeakStorage] = []

    /// The engines, in the order they run: ascending priority, then the order
    /// they were registered in.
    private var engines: [EngineEntry] = []

    /// Whether a cycle is between its latch and its publish.
    ///
    /// What decides where a write LANDS - the image the cycle is working on,
    /// or the pending slot the next one will take in - and what decides which
    /// of the two a read answers.
    private var cycling = false

    /// When the last cycle ran, on the clock the host hands in.
    private var last: Double = 0

    /// How many cycles have run.
    private var count: UInt64 = 0

    init(sync: Sync) {
        self.sync = sync
    }

    /// Takes a storage into this board's keeping.
    func hold(_ storage: HostStorage) {
        guarded.sync {
            storages.removeAll { $0.storage == nil }
            storages.append(WeakStorage(storage: storage))
        }
    }

    /// What a value stands at.
    ///
    /// INSIDE a cycle that is the image the cycle is working on, which is what
    /// makes every engine in one cycle see one picture. Outside one it is the
    /// newest thing this side knows - a write waiting to be latched, or, where
    /// none is, the last completed cycle's. So a handler that writes a value
    /// and reads it back gets what it wrote, and the cycle still runs over a
    /// picture that cannot change under it.
    func read(_ storage: HostStorage, lanes: Int) -> StateCarried {
        let bytes = guarded.sync { cycling ? storage.image : (storage.pending ?? storage.published) }

        return StateImage.carried(of: bytes, lanes: lanes)
    }

    /// Writes a value, which is a write into the image when a cycle is running
    /// and into the pending slot when none is.
    ///
    /// The stamp is bumped either way, so an engine following this value is
    /// told even where the bytes are what they already were - a finger holding
    /// a scroller still reports, and an engine that steers by it is entitled
    /// to hear every report.
    ///
    /// `forcing` is for the lanes a write MEANS even where the bytes did not
    /// move: sending a value to where it is already going is a fresh journey
    /// with a fresh waiter, and an equal setpoint would otherwise cross as
    /// nothing at all.
    func write(_ bytes: [UInt8], to storage: HostStorage, forcing forced: UInt64 = 0) {
        guarded.sync {
            storage.stamp &+= 1

            if cycling {
                storage.dirty |= HostStorage.lay(bytes, into: &storage.image) | forced
                return
            }

            var slot = storage.pending ?? storage.image

            storage.pendingMask |= HostStorage.lay(bytes, into: &slot) | forced
            storage.pending = slot
        }
    }

    /// Takes in what the HOST wrote: the named lanes only, and their dirty
    /// bits cleared.
    ///
    /// Cleared because a lane the host wrote is a lane the host already has -
    /// reading it back out would be this side telling the platform what the
    /// platform just told it, once a frame, for ever.
    ///
    /// - Parameters:
    ///   - bytes: the whole value's bytes, of which only the named lanes are
    ///     taken.
    ///   - mask: which lanes the host actually wrote.
    ///   - storage: the value.
    func told(_ bytes: [UInt8], mask: UInt64, to storage: HostStorage) {
        guarded.sync {
            storage.stamp &+= 1

            if cycling {
                _ = HostStorage.lay(bytes, into: &storage.image, only: mask)
                storage.dirty &= ~mask
                return
            }

            var slot = storage.pending ?? storage.image

            _ = HostStorage.lay(bytes, into: &slot, only: mask)
            storage.pending = slot
            storage.pendingMask &= ~mask
            storage.dirty &= ~mask
        }
    }

    /// Every state with lanes waiting to be read, in ASCENDING order, and what
    /// each of them holds - the per-frame read.
    ///
    /// The bits answered are CLEARED: what the host has been told about is not
    /// told again. What crosses is what a cycle FINISHED rather than the image
    /// a cycle is working on, so the platform never wears a half-worked-out
    /// picture.
    ///
    /// - Returns: the number, which lanes moved, and the bytes, per number.
    func dirty() -> [(number: Int32, mask: UInt64, bytes: [UInt8])] {
        guarded.sync {
            var answered: [(number: Int32, mask: UInt64, bytes: [UInt8])] = []

            for held in storages {
                guard let storage = held.storage, storage.dirty != 0,
                      let number = storage.number else { continue }

                answered.append((number, storage.dirty, storage.crossing()))
                storage.dirty = 0
            }

            return answered.sorted { $0.number < $1.number }
        }
    }

    /// One state WHOLE, with nothing cleared - what a registration reads,
    /// needing the value and where it is going both.
    ///
    /// - Parameter number: which number.
    /// - Returns: its bytes, or nil where no state rides that number any more.
    func whole(_ number: Int32) -> [UInt8]? {
        guarded.sync {
            for held in storages where held.storage?.number == number {
                return held.storage?.crossing()
            }

            return nil
        }
    }

    /// What the last cycle did, for the trace.
    private(set) var reported = CycleReport()

    /// Registers an engine, which runs from the next cycle.
    func arm(_ entry: EngineEntry) {
        guarded.sync {
            engines.append(entry)
            engines.sort { ($0.priority, $0.id) < ($1.priority, $1.id) }
        }
    }

    /// Forgets an engine - the view that declared it has gone.
    func disarm(_ id: Int) {
        guarded.sync { engines.removeAll { $0.id == id } }
    }

    /// Hands an engine the arithmetic a fresh render wrote, and a reason to
    /// run: the view has just been described, so whatever it captured has
    /// moved.
    ///
    /// - Parameters:
    ///   - id: which engine.
    ///   - run: the arithmetic, with this render's captures.
    /// - Returns: whether there was one to hand it to.
    @discardableResult
    func rearm(_ id: Int, with run: @escaping (EngineCycle) -> EngineAnswer) -> Bool {
        guarded.sync {
            guard let entry = engines.first(where: { $0.id == id }) else { return false }

            entry.run = run
            entry.armed = true
            return true
        }
    }

    /// Whether this board holds an engine under that number - what a test
    /// asks, and what says a forgotten view took its arithmetic with it.
    func holds(_ id: Int) -> Bool {
        guarded.sync { engines.contains { $0.id == id } }
    }

    /// Whether anything at all is waiting for a cycle.
    var awake: Bool {
        guarded.sync {
            stirring || storages.contains {
                $0.storage?.pending != nil || ($0.storage?.dirty ?? 0) != 0
            }
        }
    }

    /// Whether any engine has a reason to run - the half both answers about
    /// being awake share, asked with the hold already taken.
    ///
    /// STIRRED COUNTS, and it is what makes a LATCHING cycle ask for the next
    /// one: nothing ran on it, so everything the silence piled up is still
    /// waiting. The two answers differed over exactly that once, and a clock
    /// that had been told there was more to do went back to sleep anyway.
    private var stirring: Bool {
        engines.contains { $0.armed || $0.awake || $0.stirred() }
    }

    /// One cycle: everything written taken in, the engines that have a reason
    /// run, and what they wrote published.
    ///
    /// A START IS THE GAP, never a flag: the first cycle of all, and any cycle
    /// arriving after a silence longer than `mostElapsed`, LATCHES ONLY. An
    /// application that was asleep has a pile of reports and no elapsed time
    /// anybody can act on, and an engine handed a gap of minutes would put
    /// whatever it is moving through the wall.
    ///
    /// - Parameters:
    ///   - now: the instant, in milliseconds on the host's own clock.
    ///   - reducesMotion: whether the reader has asked for less movement.
    /// - Returns: what the cycle did.
    @discardableResult
    func cycle(now instant: Double, reducesMotion: Bool) -> CycleReport {
        var report = CycleReport()
        let now = max(last, instant)
        let started = count == 0 || now - last > EngineCycle.mostElapsed

        count &+= 1

        let running: [EngineEntry] = guarded.sync {
            cycling = true

            for held in storages {
                guard let storage = held.storage, let pending = storage.pending else { continue }

                storage.image = pending
                storage.dirty |= storage.pendingMask
                storage.pending = nil
                storage.pendingMask = 0
                report.latched += 1
            }

            return engines
        }

        // A start moves every engine's clock to now, so the first run after it
        // is told about ONE frame rather than about how long the application
        // was away. What it does NOT do is write down where the values stand:
        // a write made while nothing was cycling is a reason to run, and
        // noticing it here would be latching it in and then losing it.
        for entry in running where started {
            entry.lastRan = now
        }

        if !started {
            for entry in running {
                guard entry.armed || entry.awake || entry.stirred() else {
                    report.skipped += 1
                    continue
                }

                let elapsed = min(max(now - entry.lastRan, 0), EngineCycle.mostElapsed)
                let cycle = EngineCycle(
                    sync: sync,
                    now: now,
                    elapsed: elapsed,
                    count: count,
                    reducesMotion: reducesMotion)

                EngineScope.running = entry
                let answer = entry.run(cycle)
                EngineScope.running = nil

                entry.noticed()
                entry.lastRan = now
                entry.armed = false
                entry.awake = answer == .running
                report.ran += 1
            }
        }

        guarded.sync {
            for held in storages {
                guard let storage = held.storage else { continue }

                storage.published = storage.image

                if storage.dirty != 0, let number = storage.number {
                    report.written.append(number)
                }
            }

            cycling = false
            report.awake = stirring
        }

        report.written.sort()
        last = now
        reported = report

        return report
    }

    /// Everything this board holds, forgotten - what a fresh process has, and
    /// what a test asks for so its bytes do not depend on which test ran
    /// first.
    func clear() {
        guarded.sync {
            storages.removeAll()
            engines.removeAll()
            cycling = false
            last = 0
            count = 0
        }
    }

    /// A storage this board holds, weakly.
    private struct WeakStorage {
        weak var storage: HostStorage?
    }
}
