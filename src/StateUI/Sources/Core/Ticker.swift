// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A timer, as a loop that sleeps.
//
// Foundation has one and it cannot be used here: `Timer` hangs off a `RunLoop`,
// and nothing turns a RunLoop in a MAUI app on Android or Windows - the same
// reason handlers are isolated to @MainThread rather than to Swift's
// @MainActor. What IS available on every platform is Swift's own concurrency,
// because the host keeps a thread parked in `stateui_wait_work` and a resume
// wakes it; see Core/MainThread.swift.
//
// So a timer here is `Task.sleep` in a loop, and this class is that loop with
// the four things an author would otherwise write again each time:
//
// - the sleep is to a DEADLINE rather than for a length. Measured on an iPhone
//   XS, `Task.sleep(for: .seconds(1))` in a loop reaches its fifth tick at
//   5.147s - the resume costs about 20ms a lap and a loop that sleeps for the
//   interval adds every one of them up. Sleeping UNTIL the next deadline spends
//   that lateness instead: 5.003s, same device, same five seconds.
// - the loop belongs to one RUN. Starting again retires the previous loop
//   through a token, which is what stops a return to a page ending up with two
//   loops counting the same number down twice as fast.
// - a tick asks for a render, so a view that reads `ticks` follows it with
//   nothing subscribed.
// - EVERY entry point is safe from any thread, which is the one that shapes the
//   rest of this file. See below.
//
// WHY THIS IS NOT A @StateClass, when a model in an application should be.
// The macro gives a property an ordinary stored value and a setter that asks
// for a render - correct for a model written and read on the one thread MAUI
// draws on, which is where handlers run. A Ticker is not that: its whole point
// is that `onTick` may hand the work to another task and call `start()` again
// when that finishes, so `start`, `stop` and `reset` arrive from wherever that
// work ended up. Two threads writing a stored property is a data race - the
// same crossing `Renderer.guarded` exists for, where an unguarded `async let`
// corrupts the command registry and takes devices down with it.
//
// So the state lives behind a lock, the public properties read through it, and
// the renders are asked for outside it. The pattern, the queue-as-a-mutex and
// the reason it is not Foundation's NSLock are all the same as `Renderer`'s.

import Dispatch

/// A repeating timer: something to read while it counts.
///
///     @State private var ticker = Ticker(every: .seconds(1), limit: 30)
///
///     VStack {
///         Label("\((ticker.limit ?? 0) - ticker.ticks)")
///
///         Button(ticker.isRunning ? "Stop" : "Start")
///             .onClicked { ticker.isRunning ? ticker.stop() : ticker.start() }
///     }
///     .onUnloaded { ticker.stop() }
///
/// A tick writes what the interface reads and asks for the next render, so
/// there is no event to subscribe to and nothing to unsubscribe. Hold it in a
/// `@State`, which is what keeps the instance across renders, and stop it in
/// `.onUnloaded` when it should not outlive the page.
///
/// **Every method is safe to call from any thread**, which is what makes the
/// other half of this work: an `onTick` that hands its work to another task can
/// call `start()` again from wherever that work finished. See
/// `Ticker(every:isRepeating:limit:onTick:)`.
///
/// Not Foundation's `Timer`, which needs a RunLoop nothing turns on Android or
/// Windows - and not named `Timer` either, because an application that imports
/// Foundation would then have two types of that name in scope and neither would
/// win. It sleeps to a deadline rather than for a length, so a minute of
/// seconds is a minute rather than a minute and three seconds.
public final class Ticker: @unchecked Sendable {
    /// What a tick runs, if anything.
    ///
    /// Isolated to `@MainThread`, this library's own actor, so it runs where a
    /// handler runs - on the thread MAUI draws on - and may therefore read and
    /// write `@State` like any handler. It may await: the tick after it is
    /// scheduled from where this one ENDS, so a slow tick delays the next
    /// rather than overlapping it.
    public typealias Tick = @MainThread @Sendable () async -> Void

    /// The one lock. A serial queue as a mutex, for the reason
    /// `Renderer.guarded` is one: it is Dispatch rather than Foundation, and
    /// nothing here may pull ICU in.
    private let guarded = DispatchQueue(label: "StateUI.Ticker")

    private var storedInterval: Duration
    private var storedLimit: Int?
    private var storedRepeating: Bool
    private var storedTick: Tick?
    private var count = 0
    private var running = false

    /// Which run the loop belongs to. It is what makes starting twice safe: a
    /// loop suspended in its sleep cannot be cancelled from outside without
    /// holding its Task, so each run takes a number and a loop that wakes
    /// holding an old one returns rather than ticking.
    private var run = 0

    /// How long between ticks. Written while running, it takes effect from the
    /// next tick.
    ///
    /// A millisecond is the floor, and anything shorter - zero, or a negative
    /// interval arrived at by arithmetic - is that instead. See
    /// `Ticker(every:isRepeating:limit:onTick:)`.
    public var interval: Duration {
        get {
            Renderer.shared.stateRead(self)
            return guarded.sync { storedInterval }
        }
        set {
            guarded.sync { storedInterval = Ticker.usable(newValue) }
            Renderer.shared.stateChanged(self)
        }
    }

    /// How many ticks to run for, or nil to go on until stopped. A countdown is
    /// this and `ticks`: `limit - ticks` is what is left.
    ///
    /// Only meaningful while `isRepeating`, a ticker that does not repeat
    /// having stopped after one tick anyway.
    public var limit: Int? {
        get {
            Renderer.shared.stateRead(self)
            return guarded.sync { storedLimit }
        }
        set {
            guarded.sync { storedLimit = newValue }
            Renderer.shared.stateChanged(self)
        }
    }

    /// Whether it ticks again after each tick, or stops after one.
    ///
    /// True is the ordinary timer. False is a DELAY that runs `onTick` once -
    /// and, with a tick that starts it again when its work is done, a poll that
    /// can never overlap itself however long the work takes.
    ///
    /// Written while running, it is read at the next tick, as `interval` is.
    public var isRepeating: Bool {
        get {
            Renderer.shared.stateRead(self)
            return guarded.sync { storedRepeating }
        }
        set {
            guarded.sync { storedRepeating = newValue }
            Renderer.shared.stateChanged(self)
        }
    }

    /// What each tick runs, or nil for a ticker that is only read.
    ///
    /// Set it after construction when the closure needs something the
    /// initializer cannot see - a view's `@State`, or the ticker itself, both
    /// of which are still being initialized while the initializer runs:
    ///
    ///     @State private var poll = Ticker(every: .seconds(5), isRepeating: false)
    ///
    ///     VStack { … }
    ///         .onLoaded {
    ///             poll.onTick = { status = await Server.check() }
    ///             poll.start()
    ///         }
    ///
    /// A `Tick` does not throw, so anything that can has to be handled inside
    /// it - `try?`, or a `do`/`catch` that writes the failure into state.
    public var onTick: Tick? {
        get { guarded.sync { storedTick } }
        set { guarded.sync { storedTick = newValue } }
    }

    /// How many ticks have happened since the last `reset()`.
    ///
    /// Read it and the interface follows: the tick that writes it asks for a
    /// render, naming this ticker - so the render rebuilds the views that read
    /// it and leaves the rest of the tree alone.
    public var ticks: Int {
        Renderer.shared.stateRead(self)
        return guarded.sync { count }
    }

    /// Whether another tick is coming. `start()` and `stop()` are what change
    /// it.
    ///
    /// It says nothing about a tick already RUNNING: the last tick of a
    /// countdown - and the one tick of a ticker that does not repeat - clears
    /// this before running its closure, which is what lets that closure start
    /// the next round. So a false here means "nothing further is scheduled",
    /// not "the work is over".
    public var isRunning: Bool {
        Renderer.shared.stateRead(self)
        return guarded.sync { running }
    }

    /// Whether it has counted all the way to its `limit`. Always false for a
    /// ticker with no limit.
    public var isFinished: Bool {
        Renderer.shared.stateRead(self)
        return guarded.sync { finished }
    }

    /// A ticker, not started.
    ///
    ///     @State private var ticker = Ticker(every: .seconds(1), limit: 30)
    ///
    ///     // Something on every tick, with nothing outside the ticker to see:
    ///     @State private var chime = Ticker(every: .seconds(60)) {
    ///         await play(.hour)
    ///     }
    ///
    /// A tick that has to reach the ticker itself - a poll that starts the next
    /// round when its work is done - sets `onTick` after construction instead,
    /// since the ticker does not exist yet while its own initializer runs.
    ///
    /// - Parameters:
    ///   - interval: how long between ticks - or, for a ticker that does not
    ///     repeat, how long before its one tick. A millisecond is the floor.
    ///   - isRepeating: whether it ticks again after each tick. Default true.
    ///   - limit: how many ticks to run for, or nil for no end.
    ///   - onTick: what each tick runs. It may await, and the next tick is
    ///     scheduled from where it ends.
    public init(
        every interval: Duration,
        isRepeating: Bool = true,
        limit: Int? = nil,
        onTick: Tick? = nil
    ) {
        storedInterval = Ticker.usable(interval)
        storedRepeating = isRepeating
        storedLimit = limit
        storedTick = onTick
    }

    /// Starts counting, or does nothing if it is already counting.
    ///
    /// Returns at once - the loop is a task, and the first tick is one interval
    /// away. A ticker that has reached its limit starts over.
    ///
    /// Safe from any thread, which is what lets an `onTick` that moved its work
    /// to another task start the next round from there.
    public func start() {
        let mine: Int? = guarded.sync { () -> Int? in
            guard !running else { return nil }

            if finished { count = 0 }

            running = true
            run += 1

            return run
        }

        // Already running: not an error, and nothing to report.
        guard let mine else { return }

        // Outside the lock, always: the renderer takes a lock of its own, and
        // a lock taken inside a lock is how an order gets reversed.
        Renderer.shared.stateChanged(self)

        Task { @MainThread [self] in await loop(mine) }
    }

    /// Stops counting, keeping the count. Starting again goes on from there.
    ///
    /// Safe from any thread. The loop notices when it wakes, so a stop during a
    /// sleep costs at most the rest of that sleep - and nothing ticks after it.
    public func stop() {
        let changed = guarded.sync {
            let was = running
            running = false

            return was
        }

        if changed { Renderer.shared.stateChanged(self) }
    }

    /// Stops counting and puts the count back to zero. Safe from any thread.
    public func reset() {
        guarded.sync {
            running = false
            count = 0
        }

        Renderer.shared.stateChanged(self)
    }

    /// The loop, on the thread MAUI draws on.
    ///
    /// Every read of the state goes through the lock, because `stop()` and
    /// `interval` may be written from anywhere between one lap and the next.
    private nonisolated(nonsending) func loop(_ mine: Int) async {
        var deadline = ContinuousClock.now

        while true {
            deadline += guarded.sync { storedInterval }

            try? await Task.sleep(until: deadline)

            // Both halves matter: `running` is an ordinary stop, and the token
            // catches a loop whose run was replaced while it slept.
            //
            // A LAST tick stops the ticker BEFORE running the tick, not after.
            // That is what lets the tick itself start the next round - the
            // whole point of a ticker that does not repeat - because `start()`
            // on one that is still running is a no-op, and a stop written
            // afterwards would undo the round the tick just asked for.
            let (tick, last): (Tick?, Bool) = guarded.sync { () -> (Tick?, Bool) in
                guard running, run == mine else { return (nil, false) }

                count += 1

                let last = !storedRepeating || finished
                if last { running = false }

                return (storedTick ?? Ticker.nothing, last)
            }

            guard let tick else { return }

            Renderer.shared.stateChanged(self)

            await tick()

            if last { return }

            // The tick may have called stop() - or start(), which takes a new
            // run number and makes this loop the old one.
            guard guarded.sync(execute: { running && run == mine }) else { return }

            // A lap that took longer than a WHOLE interval would otherwise
            // leave the deadline far enough in the past that the laps it
            // "missed" all come due at once. The next one is measured from here
            // instead, which restores the gap between ticks.
            //
            // A whole interval, not merely "the deadline has passed": a sleep
            // overshoots its deadline by whatever the platform's floor is, and
            // clamping on THAT hands the overshoot to the next lap, where it
            // happens again - one lateness becomes one per tick, which is the
            // accumulation this loop sleeps to a deadline to avoid. It is what
            // `testTicksDoNotDriftApart` measures, and Windows's floor of
            // ~12ms against a 10ms interval is what makes the difference
            // visible; the same measurement on macOS, ten laps at
            // 100ms: 1049ms clamping on the deadline, 1005ms clamping on a
            // missed lap, against an ideal 1000ms. What the clamp is FOR is
            // unaffected - a 10ms ticker whose tick takes 30ms reads 457ms
            // either way, against 352ms with no clamp at all, which is the gap
            // being lost.
            if deadline + guarded.sync(execute: { storedInterval }) < .now { deadline = .now }
        }
    }

    /// Whether the count has reached the limit. Callers hold the lock.
    private var finished: Bool { storedLimit.map { count >= $0 } ?? false }

    /// An interval the loop can actually sleep for.
    ///
    /// Zero is not a very fast ticker and a negative one is not a ticker at
    /// all: the deadline would never reach ahead of the clock, so every sleep
    /// would return at once and the loop would tick as fast as the thread MAUI
    /// draws on could carry it - taking the interface down with it, on the one
    /// thread that draws it. A millisecond is the floor, which is well under
    /// every platform's own resolution (Windows sleeps in steps of about 12),
    /// so nothing anyone could have measured is clamped away.
    private static func usable(_ interval: Duration) -> Duration {
        max(interval, .milliseconds(1))
    }

    /// Stands in for an absent `onTick`, so the lock can answer "tick" and
    /// "do not tick" with the same optional rather than two flags.
    private static let nothing: Tick = {}
}
