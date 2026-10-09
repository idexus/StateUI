// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// What an event does when it comes again while a run of its handler is under way, and what a run that a later
/// event or its element leaving superseded may still change: nothing.
@MainActor
final class RepeatedEventTests: XCTestCase {
    override func setUp() async throws {
        _ = drainedActs()
        Renderer.shared.clearInvalidation()
    }

    /// A click while a run is under way is let go: one run, one write.
    func testAnIgnoredEventStartsNoSecondRun() async throws {
        let gate = Gate()
        var runs = 0
        let landed = State(wrappedValue: 0)
        let (renders, id) = button(.ignoreWhileRunning) {
            runs += 1
            await gate.wait()
            landed.wrappedValue += 1
        }

        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(runs, 1, "the second click came while the first ran")

        gate.open()
        try await waitUntil { landed.wrappedValue == 1 }
        renders.fire(id)
        XCTAssertEqual(runs, 2, "a click after the run starts one")
        gate.open()
        try await waitUntil { landed.wrappedValue == 2 }
    }

    /// A click cancels the run under way, which writes nothing after it - even after the new run's write.
    func testACancelledRunWritesNothingMore() async throws {
        let (first, second) = (Gate(), Gate())
        var runs = 0
        var cancelled: [Int: Bool] = [:]
        let last = State(wrappedValue: 0)
        let (renders, id) = button(.cancelPrevious) {
            runs += 1
            let run = runs
            await (run == 1 ? first : second).wait()
            cancelled[run] = Task.isCancelled
            last.wrappedValue = run
        }

        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(runs, 2)

        second.open()
        try await waitUntil { last.wrappedValue == 2 }
        first.open()
        try await waitUntil { cancelled.count == 2 }
        await settle()

        XCTAssertEqual(cancelled, [1: true, 2: false], "the first run's task was cancelled")
        XCTAssertEqual(last.wrappedValue, 2, "and its late write was refused")
    }

    /// Clicks while a run is under way wait their turn, and run in the order they came.
    func testWaitingEventsRunInTheirOrder() async throws {
        let gate = Gate()
        var started: [Int] = []
        var count = 0
        let (renders, id) = button(.waitForPrevious) {
            count += 1
            started.append(count)
            await gate.wait()
        }

        renders.fire(id)
        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(started, [1], "one runs, two wait")

        for expected in [[1, 2], [1, 2, 3]] {
            gate.open()
            try await waitUntil { started == expected }
        }
        gate.open()
    }

    /// Overlapping runs both go to their ends, and both write.
    func testOverlappingRunsBothLand() async throws {
        let gate = Gate()
        let landed = State(wrappedValue: 0)
        let (renders, id) = button(.overlap) {
            await gate.wait()
            landed.wrappedValue += 1
        }

        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(gate.waiting, 2, "two runs under way")

        gate.open()
        try await waitUntil { landed.wrappedValue == 2 }
    }

    /// A run whose element left changes nothing more: its write is refused.
    func testARunWhoseElementLeftWritesNothing() async throws {
        let gate = Gate()
        let landed = State(wrappedValue: 0)
        let (renders, id) = button(.overlap) {
            await gate.wait()
            landed.wrappedValue = 1
        }

        renders.fire(id)
        renders.render(Text("gone").node)
        gate.open()
        try await waitUntil { gate.waiting == 0 }
        await settle()

        XCTAssertEqual(landed.wrappedValue, 0, "the run outlived its element")
    }

    /// A superseded run's act is refused before it reaches the host.
    func testASupersededRunSendsNoAct() async throws {
        let gate = Gate()
        var failures: [Bool] = []
        let (renders, id) = button(.cancelPrevious) {
            await gate.wait()
            do {
                try await Dialogs.alert("late", message: "")
                failures.append(false)
            } catch {
                failures.append(error is CancellationError)
            }
        }

        renders.fire(id)
        renders.fire(id)
        _ = drainedActs()
        gate.open()
        try await waitUntil { failures.count >= 1 }

        XCTAssertEqual(failures.first, true, "the cancelled run's act failed as cancelled")
        XCTAssertEqual(drainedActs().filter { $0.name == "alert" }.count, 1, "only the live run's act left")
    }

    /// A superseded run's post is refused too.
    func testASupersededRunPostsNothing() async throws {
        let (first, second) = (Gate(), Gate())
        var runs = 0
        let posted = State(wrappedValue: 0)
        let binding = posted.projectedValue
        let (renders, id) = button(.cancelPrevious) {
            runs += 1
            let run = runs
            await (run == 1 ? first : second).wait()
            binding.post(run)
        }

        renders.fire(id)
        renders.fire(id)
        second.open()
        try await waitUntil { posted.wrappedValue == 2 }
        first.open()
        try await waitUntil { first.waiting == 0 }
        await settle()
        await settle()

        XCTAssertEqual(posted.wrappedValue, 2, "the first run's late post never landed")
    }

    /// A post's job belongs to no run: what a live run posted lands, though the
    /// run that booked the job was superseded before the job ran.
    func testAPostLandsWhicheverRunBookedItsJob() async throws {
        let gate = Gate()
        var runs = 0
        let posted = State(wrappedValue: 0)
        let binding = posted.projectedValue
        let (renders, id) = button(.cancelPrevious) {
            runs += 1
            binding.post(runs)
            await gate.wait()
        }

        renders.fire(id)
        renders.fire(id)
        await settle()

        XCTAssertEqual(posted.wrappedValue, 2, "the live run's post was refused as the superseded run's")
        gate.open()
        try await waitUntil { gate.waiting == 0 }
    }

    /// Two handlers of one event keep their own runs, each by its own word.
    func testEachHandlerOfAnEventKeepsItsOwnRuns() async throws {
        let gate = Gate()
        var ignoring = 0
        var overlapping = 0
        let renders = Renders()
        let patch = renders.render(
            Button("Go")
                .onClicked(.ignoreWhileRunning) {
                    ignoring += 1
                    await gate.wait()
                }
                .onClicked(.overlap) {
                    overlapping += 1
                    await gate.wait()
                }
                .node)
        let id = try XCTUnwrap(patch.events?["clicked"])

        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(ignoring, 1)
        XCTAssertEqual(overlapping, 2, "the second handler did not wait for the first")
        gate.open()
    }

    /// A handler with no `await` runs whole inside its event, however often it comes.
    func testAStepRunsWholeEveryTime() throws {
        var runs = 0
        let renders = Renders()
        let patch = renders.render(Button("Go").onClicked { runs += 1 }.node)
        let id = try XCTUnwrap(patch.events?["clicked"])

        renders.fire(id)
        renders.fire(id)

        XCTAssertEqual(runs, 2)
    }

    /// A write built on a value read before an `await`, which another wrote meanwhile, is said.
    func testAWriteBuiltOnAValueGoneIsSaid() async throws {
        let gate = Gate()
        let count = State(wrappedValue: 0)
        count.storage.origin = "countGone"
        let (renders, id) = button(.overlap) {
            let seen = count.wrappedValue
            await gate.wait()
            count.wrappedValue = seen + 1
        }

        renders.fire(id)
        count.wrappedValue = 10
        gate.open()
        try await waitUntil { count.wrappedValue == 1 }

        XCTAssertTrue(hasComplained("`countGone` was written by a handler that read it before an `await`"))
    }

    /// Reading the state again after the `await` builds on what it is: nothing is said.
    func testAWriteAfterReadingAgainSaysNothing() async throws {
        let gate = Gate()
        let count = State(wrappedValue: 0)
        count.storage.origin = "countReadAgain"
        let (renders, id) = button(.overlap) {
            _ = count.wrappedValue
            await gate.wait()
            count.wrappedValue += 1
        }

        renders.fire(id)
        count.wrappedValue = 10
        gate.open()
        try await waitUntil { count.wrappedValue == 11 }

        XCTAssertFalse(hasComplained("`countReadAgain`"))
    }

    /// A value read before an `await` that nobody wrote meanwhile is still what it was: nothing is said.
    func testAWriteOnAValueNobodyChangedSaysNothing() async throws {
        let gate = Gate()
        let count = State(wrappedValue: 0)
        count.storage.origin = "countKept"
        let (renders, id) = button(.overlap) {
            let seen = count.wrappedValue
            await gate.wait()
            count.wrappedValue = seen + 1
        }

        renders.fire(id)
        gate.open()
        try await waitUntil { count.wrappedValue == 1 }

        XCTAssertFalse(hasComplained("`countKept`"))
    }

    /// A button whose click runs `handler` under `repeated`, rendered, and its click's id.
    private func button(
        _ repeated: RepeatedEvent, _ handler: @escaping EventHandler
    ) -> (Renders, Int) {
        let renders = Renders()
        let patch = renders.render(Button("Go").onClicked(repeated, handler).node)
        return (renders, patch.events?["clicked"] ?? -1)
    }

    /// Turns of the UI thread until `condition` holds, for a bounded while.
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(2)

        while !condition(), Date() < deadline {
            await settle(timeout: 0)
            try await Task.sleep(nanoseconds: 200_000)
        }
        XCTAssertTrue(condition(), "never came")
    }
}

/// Where a handler waits until the test lets it go.
@MainActor
private final class Gate {
    private var continuations: [CheckedContinuation<Void, Never>] = []

    /// How many runs wait here.
    var waiting: Int { continuations.count }

    func wait() async {
        await withCheckedContinuation { continuations.append($0) }
    }

    /// Lets every run waiting here go on.
    func open() {
        let waiting = continuations
        continuations = []
        for continuation in waiting { continuation.resume() }
    }
}
