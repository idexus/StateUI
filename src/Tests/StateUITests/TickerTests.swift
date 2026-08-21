// The timer the library owns: a loop that sleeps, in a @StateClass.
//
// Real time is involved, so these are the only tests here that WAIT - each
// stands in for the host's parked thread the way MainThreadTests does, draining
// the executor until the ticker has counted what it was asked for or a generous
// deadline passes. The intervals are milliseconds; the deadlines are seconds.

import StateUIWireProbe
import Foundation
import XCTest
@testable import StateUI

final class TickerTests: XCTestCase {
    /// Drains the executor - the host's job, here done by hand - until `done`
    /// answers true or `seconds` have passed. Answers whether it happened.
    @discardableResult
    private func drain(until done: () -> Bool, within seconds: Double = 3) -> Bool {
        let deadline = Date().addingTimeInterval(seconds)

        while Date() < deadline {
            stateUIRunJobs()

            if done() { return true }

            // The sleeps are milliseconds, so this is a poll rather than a
            // spin: without it the loop burns a core waiting for a timer.
            Thread.sleep(forTimeInterval: 0.002)
        }

        return done()
    }

    func testATickerCountsWhileItRuns() {
        let ticker = Ticker(every: .milliseconds(10))

        XCTAssertFalse(ticker.isRunning, "nothing starts on its own")
        XCTAssertEqual(ticker.ticks, 0)

        ticker.start()
        XCTAssertTrue(ticker.isRunning)

        XCTAssertTrue(
            drain(until: { ticker.ticks >= 3 }),
            "three ticks of 10ms did not arrive")

        ticker.stop()
        XCTAssertFalse(ticker.isRunning)
    }

    func testAStoppedTickerCountsNoFurther() {
        let ticker = Ticker(every: .milliseconds(10))
        ticker.start()

        XCTAssertTrue(drain(until: { ticker.ticks >= 2 }))

        ticker.stop()
        let counted = ticker.ticks

        // Long enough for several more ticks, had anything been running.
        drain(until: { false }, within: 0.2)

        XCTAssertEqual(ticker.ticks, counted, "a stopped ticker went on counting")
    }

    /// The point of the run token: a second `start()` while the first loop is
    /// mid-sleep must not leave two loops counting the same property up.
    func testStartingAgainLeavesOneLoopRunning() {
        let ticker = Ticker(every: .milliseconds(40))

        ticker.start()
        ticker.stop()
        ticker.start()
        ticker.stop()
        ticker.start()

        XCTAssertTrue(drain(until: { ticker.ticks >= 1 }))

        let after = ticker.ticks
        drain(until: { false }, within: 0.05)

        XCTAssertLessThanOrEqual(
            ticker.ticks - after, 1,
            "more than one loop is counting: three starts produced three ticks a lap")
    }

    func testALimitedTickerStopsItself() {
        let ticker = Ticker(every: .milliseconds(10), limit: 3)

        ticker.start()

        XCTAssertTrue(
            drain(until: { !ticker.isRunning }),
            "a ticker with a limit of three never stopped")

        XCTAssertEqual(ticker.ticks, 3)
        XCTAssertTrue(ticker.isFinished)
    }

    /// Starting a finished ticker is starting over - what a Start button does
    /// after a countdown has run out.
    func testAFinishedTickerStartsOver() {
        let ticker = Ticker(every: .milliseconds(10), limit: 2)

        ticker.start()
        XCTAssertTrue(drain(until: { ticker.isFinished }))

        ticker.start()
        XCTAssertEqual(ticker.ticks, 0, "the count did not go back to zero")
        XCTAssertTrue(ticker.isRunning)

        ticker.stop()
    }

    func testResettingClearsTheCount() {
        let ticker = Ticker(every: .milliseconds(10))
        ticker.start()

        XCTAssertTrue(drain(until: { ticker.ticks >= 1 }))

        ticker.reset()

        XCTAssertEqual(ticker.ticks, 0)
        XCTAssertFalse(ticker.isRunning)
    }

    /// Sleeping to a DEADLINE rather than for a length: the resume costs
    /// something every lap, and a loop that sleeps for the interval adds those
    /// up. Twelve ticks are one interval each plus ONE lateness, not twelve.
    ///
    /// The interval is well above every platform's sleep floor, and that is the
    /// whole reason it is 25ms rather than the 10ms this asked for first.
    /// `Task.sleep` cannot be paced finer than about 12ms on Windows - measured
    /// under Parallels, where ten 1ms sleeps take 0.112s against 0.021s on this
    /// Mac - so a 10ms interval asks for a pace that platform cannot keep
    /// however the loop is written, and the test failed there for a reason that
    /// was never about drift. Two intervals of headroom leaves the accumulation
    /// this is about as the only thing it can measure.
    ///
    /// What the bar can SEE is a per-lap cost of a few milliseconds and up,
    /// which is what a slow platform has: Windows pays ~12ms a lap and a device
    /// ~20ms, and that is where a drifting loop turns a minute into a minute
    /// and three seconds. On this Mac the same fault reads 355-367ms against
    /// 302-307ms - measured 2026-08-06, both in the real Ticker - so the bar is
    /// deliberately not tight enough to name it here. A guard that flakes on a
    /// supported platform is worse than one with headroom.
    ///
    /// AND ON WINDOWS IT CANNOT BE MEASURED AT ALL, which is why it is skipped
    /// there rather than given a looser bar. Six runs on a QUIET machine
    /// (2026-08-13, Windows 11 arm64 under Parallels) read 0.373, 0.409, 0.586,
    /// 0.639, 0.672 and 0.708 seconds against an ideal 0.300 - so a lap costs
    /// 31-59ms where 25 was asked for, the sleep never catching up because the
    /// platform's timer granularity is wider than the interval. The fault this
    /// names is ~5ms a lap; the floor under it there is ~6-34ms a lap and
    /// jitters by 2x between runs. A bar loose enough to pass here would name
    /// the fault nowhere, which is worse than not asking on this platform.
    /// Those six came off a QUIET machine, so on Windows the granularity alone
    /// is enough and load explains nothing there. IT IS NOT THE ONLY WAY THE
    /// FLOOR RISES: a machine shared with other work pays a per-lap cost of its
    /// own, on any platform. GitHub's three-core macOS runner read 0.713s
    /// against the same ideal 0.300 - inside the Windows band - where this Mac
    /// reads 0.302-0.307, which is why the test stands aside there too.
    func testTicksDoNotDriftApart() throws {
        #if os(Windows)
        throw XCTSkip("""
            a 25ms deadline sleep costs 31-59ms here, so twelve laps land at \
            0.37-0.71s against an ideal 0.30 - the platform's floor is wider \
            than the drift this measures. The other eleven Ticker tests run.
            """)
        #endif

        // The same floor, raised by contention instead of by granularity. `CI`
        // is what a hosted runner sets and a machine this test has to itself
        // does not, which is the closest thing to "am I being timed fairly".
        try XCTSkipIf(
            ProcessInfo.processInfo.environment["CI"] != nil,
            """
            a shared runner charges what it likes for a 25ms lap - twelve took \
            0.713s here against an ideal 0.300, which is the Windows floor \
            under another name. The other eleven Ticker tests run.
            """)

        let ticker = Ticker(every: .milliseconds(25), limit: 12)
        let start = ContinuousClock.now

        ticker.start()
        XCTAssertTrue(drain(until: { ticker.isFinished }))

        let taken = start.duration(to: .now)

        XCTAssertLessThan(
            taken, .milliseconds(400),
            "twelve 25ms ticks took \(taken) - the lateness of each lap is accumulating")
    }

    // MARK: - What a tick runs

    func testEachTickRunsTheClosureItWasGiven() {
        nonisolated(unsafe) var ran = 0
        let ticker = Ticker(every: .milliseconds(10), limit: 3) { ran += 1 }

        ticker.start()

        XCTAssertTrue(drain(until: { !ticker.isRunning }))
        XCTAssertEqual(ran, 3, "the closure ran \(ran) times for three ticks")
    }

    func testATickerThatDoesNotRepeatTicksOnce() {
        nonisolated(unsafe) var ran = 0
        let ticker = Ticker(every: .milliseconds(10), isRepeating: false) { ran += 1 }

        ticker.start()

        XCTAssertTrue(drain(until: { !ticker.isRunning }))

        // Long enough for several more, had it repeated.
        drain(until: { false }, within: 0.1)

        XCTAssertEqual(ran, 1)
        XCTAssertEqual(ticker.ticks, 1)
    }

    /// The reason a last tick stops the ticker BEFORE running the closure: a
    /// poll hands its work to another task and starts the next round when that
    /// work is done. `start()` on a ticker still marked running would be a
    /// no-op, and the round would be lost in silence.
    func testATickCanStartTheNextRoundWhenItsWorkIsDone() {
        nonisolated(unsafe) var rounds = 0
        let ticker = Ticker(every: .milliseconds(10), isRepeating: false)

        ticker.onTick = { [ticker] in
            // Work of unknown length, off this thread - what a poll does.
            await Task.detached { try? await Task.sleep(for: .milliseconds(5)) }.value

            rounds += 1

            if rounds < 3 { ticker.start() }
        }

        ticker.start()

        XCTAssertTrue(
            drain(until: { rounds >= 3 }, within: 5),
            "the poll stopped after \(rounds) round(s)")

        XCTAssertFalse(ticker.isRunning, "the last round left it running")
    }

    /// A tick longer than the interval delays the next one rather than making
    /// the missed laps all come due at once.
    func testASlowTickDoesNotMakeTheNextOnesComeAtOnce() {
        nonisolated(unsafe) var ran = 0
        let ticker = Ticker(every: .milliseconds(10), limit: 3) {
            try? await Task.sleep(for: .milliseconds(60))
            ran += 1
        }

        let start = ContinuousClock.now
        ticker.start()

        // For `ran`, not for `isRunning`: a LAST tick clears the flag before it
        // runs the closure, so that the closure may start the next round.
        XCTAssertTrue(drain(until: { ran >= 3 }, within: 5))

        let taken = start.duration(to: .now)

        XCTAssertEqual(ran, 3)
        XCTAssertGreaterThan(
            taken, .milliseconds(180),
            "three 60ms ticks came back in \(taken) - the laps were caught up all at once")
    }

    // MARK: - From any thread

    /// The whole reason the state is behind a lock: an `onTick` may hand its
    /// work to another task, so `start`, `stop` and `reset` arrive from
    /// wherever that work ended up.
    func testTheControlsAreSafeFromManyThreadsAtOnce() {
        let ticker = Ticker(every: .milliseconds(5))

        DispatchQueue.concurrentPerform(iterations: 300) { turn in
            switch turn % 4 {
            case 0: ticker.start()
            case 1: ticker.stop()
            case 2: ticker.reset()
            default: _ = ticker.ticks + (ticker.isRunning ? 1 : 0)
            }
        }

        ticker.stop()
        drain(until: { false }, within: 0.1)

        XCTAssertFalse(ticker.isRunning, "a stop from this thread did not take")

        let counted = ticker.ticks
        drain(until: { false }, within: 0.1)

        XCTAssertEqual(ticker.ticks, counted, "a loop survived the stop")
    }

    func testStartingFromAnotherThreadCounts() {
        let ticker = Ticker(every: .milliseconds(10))

        DispatchQueue.global().async { ticker.start() }

        XCTAssertTrue(
            drain(until: { ticker.ticks >= 2 }),
            "a ticker started off the UI thread never counted")

        ticker.stop()
    }

    // MARK: - What the interface hears

    /// A tick writes what the interface reads and asks for the next render.
    func testATickAsksForARender() {
        let ticker = Ticker(every: .milliseconds(10))

        // A render is what clears the flag, so this is how a test gets to a
        // state where "needs render" means the tick and nothing before it.
        _ = WireProbe.decodeMessage(Renderer.shared.renderWire(baseline: 0))
        XCTAssertFalse(Renderer.shared.needsRender)

        ticker.start()
        XCTAssertTrue(drain(until: { ticker.ticks >= 1 }))
        ticker.stop()

        XCTAssertTrue(Renderer.shared.needsRender, "the tick did not ask for a render")
    }

    /// Every settable property is one a view can read, so every one of them
    /// asks for the render that shows the new value.
    func testWritingAPropertyAsksForARender() {
        let ticker = Ticker(every: .milliseconds(10))
        let mine = ObjectIdentifier(ticker)

        for write in [
            ("interval", { ticker.interval = .milliseconds(50) }),
            ("isRepeating", { ticker.isRepeating = false }),
            ("limit", { ticker.limit = 3 }),
        ] as [(String, () -> Void)] {
            Renderer.shared.clearInvalidation()
            write.1()

            XCTAssertTrue(
                Renderer.shared.pendingChanges.contains(mine),
                "writing \(write.0) asked for no render, so a view reading it "
                + "would go on showing the old value")
        }
    }

    // MARK: - An interval the loop can sleep for

    /// Zero is not a very fast ticker and a negative one is not a ticker at
    /// all: the deadline would never move ahead of the clock and the loop would
    /// spin on the thread MAUI draws on. A millisecond is the floor.
    func testAnIntervalOfNothingIsGivenAFloor() {
        XCTAssertEqual(Ticker(every: .zero).interval, .milliseconds(1))
        XCTAssertEqual(Ticker(every: .seconds(-5)).interval, .milliseconds(1))

        let ticker = Ticker(every: .seconds(1))
        ticker.interval = .zero
        XCTAssertEqual(ticker.interval, .milliseconds(1), "the floor is the setter's too")
    }

    /// And the floor is what makes such a ticker END: it counts its limit and
    /// stops, where a loop with no gap would still be running.
    func testATickerAskedForNoGapStillFinishes() {
        let ticker = Ticker(every: .zero, limit: 3)

        ticker.start()

        XCTAssertTrue(
            drain(until: { ticker.isFinished }, within: 2),
            "a ticker with no interval never reached its limit")

        XCTAssertEqual(ticker.ticks, 3)
        XCTAssertFalse(ticker.isRunning)
    }
}
