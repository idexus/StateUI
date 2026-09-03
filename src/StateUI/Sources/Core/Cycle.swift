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
//                 since IT last ran.
//   (3) WRITE     what moved is published, and the host reads it out.
//
// The board is what holds one such cycle: an image, its engines, and one hold
// over both. There is one per SYNC - one clock, one cycle - and today the only
// sync is the display's own frame.

// The hold is a serial queue for the reason `Core/State.swift` gives: libdispatch
// is on every platform this targets, and Foundation's locks bring ICU on Windows.
import Dispatch

/// What drives a cycle. This library's own.
///
/// No raw value: a board is an index the host is handed, never a number on the
/// wire.
public enum Sync: Sendable {
    /// The display's own frame - what every value on screen moves by.
    case vsync
}

/// What an engine answers about its next cycle. This library's own.
public enum EngineState: Sendable {
    /// Run me again next frame: something is still on its way somewhere.
    case moving

    /// Nothing more to do until something I follow moves.
    case still
}

/// What one run of an engine is handed. This library's own.
public struct EngineCycle: Sendable {
    /// Which clock this cycle belongs to.
    public let sync: Sync

    /// Milliseconds on that clock since its first cycle.
    public let now: Double

    /// Milliseconds since THIS ENGINE last ran - above nought, and never above
    /// `mostElapsed`.
    ///
    /// Per engine rather than per cycle, because an engine that follows a
    /// value nothing has moved does not run, and the one that does run then
    /// has to be told the whole of the time it missed.
    public let elapsed: Double

    /// The most one cycle is ever told elapsed: a tenth of a second.
    ///
    /// Longer than this is not a slow frame, it is an application that was
    /// asleep - and arithmetic handed a gap of minutes puts whatever it is
    /// moving through the wall. A motion that was interrupted for that long
    /// arrives instead.
    public static let mostElapsed = 100.0

    /// How many cycles this board has run, this one included.
    public let count: UInt64

    /// Whether the reader has asked for less movement, which every engine that
    /// draws a motion has to answer.
    public let reducesMotion: Bool
}

/// Memory an engine keeps between cycles and nothing else sees - a phase, a
/// counter, a snapshot of where something was. This library's own.
///
///     @CycleState private var phase = Phase(Step.waiting)
///
/// Any Swift type: no lanes, no bytes, nothing crossing. Kept like `@State` -
/// found by the property's own name, and the same value across every render.
/// AN ENGINE THAT READ ONE FOLLOWS IT, so a handler writing `phase.go(to:)`
/// wakes the engine that switches on it, exactly as a written number does.
@propertyWrapper
public final class CycleState<Value>: @unchecked Sendable {
    /// The value, across every render.
    fileprivate(set) var held: CycleStateStorage<Value>

    /// State that will hold what it says.
    ///
    /// - Parameter wrappedValue: what it holds before anything writes it.
    public init(wrappedValue: Value) {
        held = CycleStateStorage(wrappedValue)
    }

    /// Where the value stands. Reading it inside an engine says that engine
    /// follows it; reading it anywhere else records nothing.
    public var wrappedValue: Value {
        get {
            EngineScope.read(held)
            return held.value
        }
        set { held.write(newValue) }
    }

    /// What `$phase` gives: the state itself, for a signature that takes one.
    public var projectedValue: CycleState<Value> { self }
}

extension CycleState: StateBox {
    /// Takes over the other wrapper's storage, so the two are one value from
    /// here on.
    func adopt(from other: AnyObject) {
        guard let other = other as? CycleState<Value>, other !== self else { return }

        held = other.held
    }

    /// Tells the value what the author calls it, as a state is told.
    func named(_ path: String) {
        held.origin = BuildScope.readable(path)
    }
}

/// What a `@CycleState` IS across every render.
///
/// A stamp beside the value, so an engine can be asked "has anything you read
/// moved?" the same way it is asked about a number - which is what makes a
/// handler's write wake the engine that switches on it.
final class CycleStateStorage<Value>: @unchecked Sendable, NamedState, AnyCycleStateStorage {
    private let guarded = DispatchQueue(label: "StateUI.CycleState")
    private var held: Value

    /// How many times it has been written.
    nonisolated(unsafe) private(set) var stamp: Int = 0

    /// What the author calls it - the reflection walk's.
    nonisolated(unsafe) var origin: String?

    init(_ value: Value) {
        held = value
    }

    /// The value, read whole.
    var value: Value { guarded.sync { held } }

    /// The value, written whole, and counted.
    func write(_ newValue: Value) {
        guarded.sync {
            held = newValue
            stamp += 1
        }
    }
}

/// The part of a `@CycleState` storage an engine's bookkeeping needs, without
/// knowing what the value is.
protocol AnyCycleStateStorage: AnyObject {
    /// How many times it has been written.
    var stamp: Int { get }
}

/// What is being run right now, so a read can say who read it.
///
/// An engine FOLLOWS whatever it read on its last run, and this is how that is
/// noticed: the run is bracketed, and every `@CycleState` read inside the
/// bracket is recorded against it. A read outside one records nothing, which
/// is what a handler's read is.
enum EngineScope {
    /// What is running, if anything is. One board runs one engine at a time,
    /// and a second board runs on a thread of its own - which is why this is
    /// per thread once there is one.
    nonisolated(unsafe) static var running: EngineEntry?

    /// Records that the engine now running read this state.
    static func read(_ storage: AnyCycleStateStorage) {
        running?.read(storage)
    }
}

/// An engine as the TREE carries it, before the differ has given it a number.
///
/// The closure captures the view BY VALUE, which is what makes an engine safe
/// to run on the frame thread: everything it reads that can move is a number or a
/// `@CycleState`, and everything else is a copy of what the render saw.
struct EngineDeclaration {
    /// The states whose movement is a reason to run it.
    let follows: [HostStorage]

    /// Which clock it runs on.
    let sync: Sync

    /// Where it comes in the order, ascending.
    let priority: Double

    /// The arithmetic.
    let run: (EngineCycle) -> EngineState
}

/// One registered engine and everything the board remembers about it.
final class EngineEntry {
    /// What the differ registered it under, which is also its tie-break.
    let id: Int

    /// Where it comes in the order, ascending; ties by `id`.
    let priority: Double

    /// Which clock it runs on.
    let sync: Sync

    /// The arithmetic itself.
    ///
    /// A VAR because a render REWRITES it: the closure captured the view by
    /// value, so the one a render just described is the one holding this
    /// render's captures. An engine under a memo token that held is not
    /// rewritten, and goes on running the captures it had - which is what the
    /// token said.
    var run: (EngineCycle) -> EngineState

    /// What the author calls the view that declared it, for a complaint that
    /// has to name one.
    let origin: String?

    /// The states it was told to follow.
    let follows: [HostStorage]

    /// The `@CycleState`s it read on its last run, weakly - it follows those
    /// too, and a state nothing else holds is one the engine has let go of.
    private var states: [WeakCycleState] = []

    /// The stamps of everything it follows, as they stood when it last ran.
    private var seen: [ObjectIdentifier: Int] = [:]

    /// Whether a render has described the view since it last ran, which is a
    /// reason to run whatever moved.
    var armed = true

    /// Whether its own last answer was `.moving`.
    var awake = false

    /// When it last ran, on the board's own clock.
    var lastRan: Double = 0

    /// When it last dirtied a lane. What the ten-second bound is measured
    /// from: an engine awake that long having written nothing is one nobody
    /// can see, and it is put still.
    var lastWrote: Double = 0

    init(
        id: Int,
        priority: Double,
        sync: Sync,
        follows: [HostStorage],
        origin: String?,
        run: @escaping (EngineCycle) -> EngineState
    ) {

        self.id = id
        self.priority = priority
        self.sync = sync
        self.follows = follows
        self.origin = origin
        self.run = run
    }

    /// Records that this run read a `@CycleState`.
    func read(_ storage: AnyCycleStateStorage) {
        guard !states.contains(where: { $0.storage === storage }) else { return }

        states.append(WeakCycleState(storage: storage))
    }

    /// Whether anything it follows has been written since it last ran.
    func stirred() -> Bool {
        for storage in follows where seen[ObjectIdentifier(storage)] != storage.stamp {
            return true
        }

        for state in states {
            guard let storage = state.storage else { continue }

            if seen[ObjectIdentifier(storage)] != storage.stamp { return true }
        }

        return false
    }

    /// Writes down where everything it follows stood, now that it has run.
    func noticed() {
        for storage in follows {
            seen[ObjectIdentifier(storage)] = storage.stamp
        }

        states.removeAll { $0.storage == nil }

        for state in states {
            guard let storage = state.storage else { continue }

            seen[ObjectIdentifier(storage)] = storage.stamp
        }
    }

    /// A `@CycleState` an engine read, held weakly.
    private struct WeakCycleState {
        weak var storage: AnyCycleStateStorage?
    }
}

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

    /// Every storage that belongs to this board, weakly: a number is the view's,
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

    /// Every number with lanes waiting to be read, in ASCENDING order, and what
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

                answered.append((number, storage.dirty, storage.published))
                storage.dirty = 0
            }

            return answered.sorted { $0.number < $1.number }
        }
    }

    /// One number WHOLE, with nothing cleared - what a registration reads,
    /// needing the value and where it is going both.
    ///
    /// - Parameter number: which number.
    /// - Returns: its bytes, or nil where no number rides that number any more.
    func whole(_ number: Int32) -> [UInt8]? {
        guarded.sync {
            for held in storages where held.storage?.number == number {
                return held.storage?.published
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
    func rearm(_ id: Int, with run: @escaping (EngineCycle) -> EngineState) -> Bool {
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
                entry.awake = answer == .moving
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
