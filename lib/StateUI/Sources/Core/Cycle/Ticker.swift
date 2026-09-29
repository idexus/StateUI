// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A repeating timer as a loop that sleeps to a deadline, safe to drive from any
// thread.
// Design: docs/design/core/cycle.md#the-ticker

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
///     .onDestroying { ticker.stop() }
///
/// A tick asks for a render, so a view reading `ticks` follows it with nothing
/// subscribed. Hold it in a `@State`, and stop it in `.onDestroying` when it
/// should not outlive the view. Every method is safe from any thread. It sleeps
/// to a deadline, so a minute of seconds is a minute.
public final class Ticker: @unchecked Sendable {
    /// What a tick runs. It runs on `@MainActor`, so it may read and write `@State`;
    /// it may await, and the next tick is scheduled from where it ends.
    public typealias Tick = @MainActor @Sendable () async -> Void

    /// The one lock.
    private let guarded = Lock()

    private var storedInterval: Duration
    private var storedLimit: Int?
    private var storedRepeating: Bool
    private var storedTick: Tick?
    private var count = 0
    private var running = false

    /// Which run the loop belongs to: a loop waking with an old number returns.
    private var run = 0

    /// How long between ticks; written while running, it applies from the next tick.
    /// A millisecond is the floor.
    public var interval: Duration {
        get {
            Renderer.shared.stateRead(self)
            return guarded.withLock { storedInterval }
        }
        set {
            guarded.withLock { storedInterval = Ticker.usable(newValue) }
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
            return guarded.withLock { storedLimit }
        }
        set {
            guarded.withLock { storedLimit = newValue }
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
            return guarded.withLock { storedRepeating }
        }
        set {
            guarded.withLock { storedRepeating = newValue }
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
    ///         .onCreated {
    ///             poll.onTick = { status = await Server.check() }
    ///             poll.start()
    ///         }
    ///
    /// A `Tick` does not throw, so anything that can has to be handled inside
    /// it - `try?`, or a `do`/`catch` that writes the failure into state.
    public var onTick: Tick? {
        get { guarded.withLock { storedTick } }
        set { guarded.withLock { storedTick = newValue } }
    }

    /// How many ticks have happened since the last `reset()`.
    ///
    /// Read it and the interface follows: the tick that writes it asks for a
    /// render, naming this ticker - so the render rebuilds the views that read
    /// it and leaves the rest of the tree alone.
    public var ticks: Int {
        Renderer.shared.stateRead(self)
        return guarded.withLock { count }
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
        return guarded.withLock { running }
    }

    /// Whether it has counted all the way to its `limit`. Always false for a
    /// ticker with no limit.
    public var isFinished: Bool {
        Renderer.shared.stateRead(self)
        return guarded.withLock { finished }
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

    /// Starts counting, or does nothing if it is already counting. Returns at once;
    /// the first tick is an interval away, and a ticker at its limit starts over.
    /// Safe from any thread.
    public func start() {
        let mine: Int? = guarded.withLock { () -> Int? in
            guard !running else { return nil }

            if finished { count = 0 }

            running = true
            run += 1

            return run
        }

        // Already running: not an error, and nothing to report.
        guard let mine else { return }

        // Outside the lock: the renderer takes a lock of its own.
        Renderer.shared.stateChanged(self)

        Task { @MainActor [self] in await loop(mine) }
    }

    /// Stops counting, keeping the count. Starting again goes on from there.
    ///
    /// Safe from any thread. The loop notices when it wakes, so a stop during a
    /// sleep costs at most the rest of that sleep - and nothing ticks after it.
    public func stop() {
        let changed = guarded.withLock {
            let was = running
            running = false

            return was
        }

        if changed { Renderer.shared.stateChanged(self) }
    }

    /// Stops counting and puts the count back to zero. Safe from any thread.
    public func reset() {
        guarded.withLock {
            running = false
            count = 0
        }

        Renderer.shared.stateChanged(self)
    }

    /// The loop, on the UI thread; every read of the state goes through the lock.
    private nonisolated(nonsending) func loop(_ mine: Int) async {
        var deadline = ContinuousClock.now

        while true {
            deadline += guarded.withLock { storedInterval }

            try? await Task.sleep(until: deadline)

            // A stop and a replaced run both end the loop. The last tick stops the ticker
            // before it runs, so the tick itself can start the next round.
            // Design: docs/design/core/cycle.md#the-ticker
            let (tick, last): (Tick?, Bool) = guarded.withLock { () -> (Tick?, Bool) in
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

            // The tick may have stopped the ticker, or started a new run.
            guard guarded.withLock({ running && run == mine }) else { return }

            // A lap longer than a whole interval restarts the deadline from now, so missed
            // laps do not all come due at once.
            // Design: docs/design/core/cycle.md#the-ticker
            if deadline + guarded.withLock({ storedInterval }) < .now { deadline = .now }
        }
    }

    /// Whether the count has reached the limit. Callers hold the lock.
    private var finished: Bool { storedLimit.map { count >= $0 } ?? false }

    /// An interval the loop can sleep for: a millisecond at least.
    private static func usable(_ interval: Duration) -> Duration {
        max(interval, .milliseconds(1))
    }

    /// Stands in for an absent `onTick`, so one optional answers "tick" or not.
    private static let nothing: Tick = {}
}
