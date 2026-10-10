// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// What a gate does with an event that comes while a run is under way through it - a handler's own, or one gate
/// shared by several - and what a run that a later event or its element leaving superseded may still change:
/// nothing.
@MainActor
final class GateTests: XCTestCase {
    override func setUp() async throws {
        _ = drainedActs()
        Renderer.shared.clearInvalidation()
    }

    /// A click while a run is under way is let go: one run, one write.
    func testAnIgnoredEventStartsNoSecondRun() async throws {
        let latch = Latch()
        var runs = 0
        let landed = State(wrappedValue: 0)
        let (renders, id) = button(gate: .ignoreWhileRunning) {
            runs += 1
            await latch.wait()
            landed.wrappedValue += 1
        }

        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(runs, 1, "the second click came while the first ran")

        latch.open()
        try await waitUntil { landed.wrappedValue == 1 }
        renders.fire(id)
        XCTAssertEqual(runs, 2, "a click after the run starts one")
        latch.open()
        try await waitUntil { landed.wrappedValue == 2 }
    }

    /// Two buttons through one gate share its policy: while one's run is under way, the other's click is let go.
    func testTwoButtonsThroughOneGateShareItsPolicy() async throws {
        let latch = Latch()
        let document = SharedGate(.ignoreWhileRunning)
        var saves = 0, deletes = 0
        let (renders, save, delete) = twoButtons(
            Button("Save").onClicked(gate: document) { saves += 1; await latch.wait() },
            Button("Delete").onClicked(gate: document) { deletes += 1 })

        renders.fire(save)
        renders.fire(delete)
        XCTAssertEqual([saves, deletes], [1, 0], "the delete came while the save ran through the same gate")

        latch.open()
        try await waitUntil { !document.isBusy }
        renders.fire(delete)
        XCTAssertEqual(deletes, 1, "a click after the run passes")
    }

    /// Each handler's own gate stands apart: a run of one button holds no click of another back.
    func testEachHandlersOwnGateStandsApart() async throws {
        let latch = Latch()
        var first = 0, second = 0
        let (renders, a, b) = twoButtons(
            Button("A").onClicked(gate: .ignoreWhileRunning) { first += 1; await latch.wait() },
            Button("B").onClicked(gate: .ignoreWhileRunning) { second += 1; await latch.wait() })

        renders.fire(a)
        renders.fire(b)
        renders.fire(a)
        XCTAssertEqual([first, second], [1, 1], "each its own, and each lets its own repeat go")

        latch.open()
        try await waitUntil { latch.waiting == 0 }
    }

    /// A gate is busy while a run is under way through it - a state a body reads to dim a control.
    func testAGateIsBusyWhileARunIsUnderWay() async throws {
        let latch = Latch()
        let saving = SharedGate(.ignoreWhileRunning)
        let (renders, id) = button(gate: saving) { await latch.wait() }

        XCTAssertFalse(saving.isBusy)
        renders.fire(id)
        XCTAssertTrue(saving.isBusy, "a run is under way")

        latch.open()
        try await waitUntil { !saving.isBusy }
    }

    /// An element leaving ends its own runs in a gate it shares, and the others' stand.
    func testAnElementLeavingEndsOnlyItsOwnRunsInASharedGate() async throws {
        let latch = Latch()
        let uploads = SharedGate(.none)
        let first = State(wrappedValue: 0), second = State(wrappedValue: 0)
        let renders = Renders()
        func tree(_ both: Bool) -> Node {
            VStack {
                if both {
                    Button("First").onClicked(gate: uploads) { await latch.wait(); first.wrappedValue = 1 }
                }
                Button("Second").onClicked(gate: uploads) { await latch.wait(); second.wrappedValue = 1 }
            }.node
        }
        let patch = renders.render(tree(true))
        let ids = clickedIds(in: patch)
        renders.fire(ids[0])
        renders.fire(ids[1])

        _ = renders.render(tree(false))
        latch.open()
        try await waitUntil { !uploads.isBusy }
        await settle()

        XCTAssertEqual(first.wrappedValue, 0, "the run of the button that left changed nothing")
        XCTAssertEqual(second.wrappedValue, 1, "the other's run through the same gate landed")
    }

    /// A click cancels the run under way, which writes nothing after it - even after the new run's write.
    func testACancelledRunWritesNothingMore() async throws {
        let (first, second) = (Latch(), Latch())
        var runs = 0
        var cancelled: [Int: Bool] = [:]
        let last = State(wrappedValue: 0)
        let (renders, id) = button(gate: .cancelPrevious) {
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
        let latch = Latch()
        var started: [Int] = []
        var count = 0
        let (renders, id) = button(gate: .waitForPrevious) {
            count += 1
            started.append(count)
            await latch.wait()
        }

        renders.fire(id)
        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(started, [1], "one runs, two wait")

        for expected in [[1, 2], [1, 2, 3]] {
            latch.open()
            try await waitUntil { started == expected }
        }
        latch.open()
    }

    /// Overlapping runs both go to their ends, and both write.
    func testOverlappingRunsBothLand() async throws {
        let latch = Latch()
        let landed = State(wrappedValue: 0)
        let (renders, id) = button(gate: .none) {
            await latch.wait()
            landed.wrappedValue += 1
        }

        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(latch.waiting, 2, "two runs under way")

        latch.open()
        try await waitUntil { landed.wrappedValue == 2 }
    }

    /// A run whose element left changes nothing more: its write is refused.
    func testARunWhoseElementLeftWritesNothing() async throws {
        let latch = Latch()
        let landed = State(wrappedValue: 0)
        let (renders, id) = button(gate: .none) {
            await latch.wait()
            landed.wrappedValue = 1
        }

        renders.fire(id)
        renders.render(Text("gone").node)
        latch.open()
        try await waitUntil { latch.waiting == 0 }
        await settle()

        XCTAssertEqual(landed.wrappedValue, 0, "the run outlived its element")
    }

    /// A run is counted under way until it ends, in the tally a host prints - where a run that never ends shows.
    func testARunIsCountedUnderWayUntilItEnds() async throws {
        let latch = Latch()
        let before = HostBoundary.tally.runs
        let (renders, id) = button(gate: .none) { await latch.wait() }

        renders.fire(id)
        XCTAssertEqual(HostBoundary.tally.runs, before + 1)

        latch.open()
        try await waitUntil { HostBoundary.tally.runs == before }
    }

    /// An element leaving cancels the runs of its events in their names' order, every time.
    func testAnElementLeavingCancelsItsEventsRunsInNameOrder() async throws {
        nonisolated(unsafe) var cancelled: [String] = []
        let latch = Latch()
        var chimes = Chimes()
        for event in ChimesContract.events.reversed() {
            chimes = chimes.onEvent(event, gate: .none) {
                await withTaskCancellationHandler { await latch.wait() } onCancel: { cancelled.append(event.name) }
            }
        }
        let renders = Renders()
        let patch = renders.render(chimes.node)
        for event in ChimesContract.events.reversed() {
            renders.fire(try XCTUnwrap(patch.events?[Event(event.name)]))
        }
        XCTAssertEqual(latch.waiting, ChimesContract.events.count)

        renders.render(Text("gone").node)

        XCTAssertEqual(cancelled, ChimesContract.events.map(\.name).sorted())
        latch.open()
        try await waitUntil { latch.waiting == 0 }
    }

    /// An element leaving cancels the runs its walk began - its `.onCreated` here - in the order they were written.
    func testAnElementLeavingCancelsItsWalksRunsInTheOrderWritten() async throws {
        nonisolated(unsafe) var cancelled: [Int] = []
        let latch = Latch()
        var made = Text("here")
        for index in 0..<8 {
            made = made.onCreated {
                await withTaskCancellationHandler { await latch.wait() } onCancel: { cancelled.append(index) }
            }
        }
        let renders = Renders()
        renders.render(made.node)
        XCTAssertEqual(latch.waiting, 8)

        renders.render(Button("gone").node)

        XCTAssertEqual(cancelled, Array(0..<8))
        latch.open()
        try await waitUntil { latch.waiting == 0 }
    }

    /// A superseded run's act is refused before it reaches the host.
    func testASupersededRunSendsNoAct() async throws {
        let latch = Latch()
        var failures: [Bool] = []
        let (renders, id) = button(gate: .cancelPrevious) {
            await latch.wait()
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
        latch.open()
        try await waitUntil { failures.count >= 1 }

        XCTAssertEqual(failures.first, true, "the cancelled run's act failed as cancelled")
        XCTAssertEqual(drainedActs().filter { $0.name == "alert" }.count, 1, "only the live run's act left")
    }

    /// A superseded run's post is refused too.
    func testASupersededRunPostsNothing() async throws {
        let (first, second) = (Latch(), Latch())
        var runs = 0
        let posted = State(wrappedValue: 0)
        let binding = posted.projectedValue
        let (renders, id) = button(gate: .cancelPrevious) {
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
        let latch = Latch()
        var runs = 0
        let posted = State(wrappedValue: 0)
        let binding = posted.projectedValue
        let (renders, id) = button(gate: .cancelPrevious) {
            runs += 1
            binding.post(runs)
            await latch.wait()
        }

        renders.fire(id)
        renders.fire(id)
        await settle()

        XCTAssertEqual(posted.wrappedValue, 2, "the live run's post was refused as the superseded run's")
        latch.open()
        try await waitUntil { latch.waiting == 0 }
    }

    /// A task under a superseded run changes nothing, after the run's own body
    /// ended too - whatever other runs are under way.
    func testATaskUnderASupersededRunChangesNothingAfterTheRunEnds() async throws {
        let (outer, inner) = (Latch(), [Latch(), Latch()])
        var runs = 0
        let status = State(wrappedValue: "")
        let (renders, id) = button(gate: .cancelPrevious) {
            runs += 1
            let run = runs
            Task { await inner[run - 1].wait(); status.wrappedValue = "late \(run)" }
            await outer.wait()
        }

        renders.fire(id)
        renders.fire(id)
        outer.open()
        try await waitUntil { outer.waiting == 0 }
        await settle()
        inner[1].open()
        try await waitUntil { status.wrappedValue == "late 2" }
        inner[0].open()
        try await waitUntil { inner[0].waiting == 0 }
        await settle()

        XCTAssertEqual(status.wrappedValue, "late 2", "the superseded run's task wrote once no other run was superseded")
    }

    /// Work that must outlive its run - a save after the sheet closed - is given a task of its own, detached: it
    /// belongs to no run, so the run being superseded refuses nothing it writes. The pattern the refusal teaches.
    func testWorkGivenADetachedTaskOutlivesItsRun() async throws {
        let latch = Latch()
        let saved = State(wrappedValue: "")
        let (renders, id) = button(gate: .none) {
            Task.detached { await Self.save(into: saved, after: latch) }
        }

        renders.fire(id)
        try await waitUntil { latch.waiting == 1 }
        renders.render(Text("gone").node)
        latch.open()
        try await waitUntil { saved.wrappedValue == "saved" }

        XCTAssertEqual(saved.wrappedValue, "saved", "the detached work's write landed after its element left")
    }

    /// The save a detached task runs: the model's own work, on `MainActor`.
    private static func save(into saved: State<String>, after latch: Latch) async {
        await latch.wait()
        saved.wrappedValue = "saved"
    }

    /// A refused write says what to do: give the work that must outlive its element a task of its own.
    func testARefusedWriteSaysWhereTheWorkBelongs() async throws {
        let latch = Latch()
        let landed = State(wrappedValue: 0)
        landed.storage.name(once: "refusalTeaches")
        let (renders, id) = button(gate: .none) {
            await latch.wait()
            landed.wrappedValue = 1
        }

        renders.fire(id)
        renders.render(Text("gone").node)
        latch.open()
        try await waitUntil { latch.waiting == 0 }
        await settle()

        XCTAssertTrue(hasComplained("`refusalTeaches`"), "the refusal names the state")
        XCTAssertTrue(hasComplained("Task.detached"), "and says where the work belongs")
    }

    /// A refusal reaches the application's route outside the run it refused: a route that posts what it heard to a
    /// state is not refused with the run.
    func testARefusalReachesTheRouteOutsideTheRunItRefused() async throws {
        let latch = Latch()
        let landed = State(wrappedValue: 0)
        landed.storage.name(once: "routedRefusal")
        let heard = State(wrappedValue: [String]())
        let route = heard.projectedValue
        Complaints.route { words in route.post { $0 + [words] } }
        defer { Complaints.route(to: nil) }
        let (renders, id) = button(gate: .none) {
            await latch.wait()
            landed.wrappedValue = 1
        }

        renders.fire(id)
        renders.render(Text("gone").node)
        latch.open()
        try await waitUntil { heard.wrappedValue.contains { $0.contains("`routedRefusal`") } }

        XCTAssertTrue(heard.wrappedValue.contains { $0.contains("`routedRefusal`") }, "the route heard the refusal")
    }

    /// A ticker started by a run keeps counting once that run is superseded: its
    /// loop is the library's, and belongs to no run.
    func testATickerStartedByASupersededRunKeepsCounting() async throws {
        let latch = Latch()
        let ticked = State(wrappedValue: 0)
        let ticker = Ticker(every: .milliseconds(5)) { ticked.wrappedValue += 1 }
        var runs = 0
        let (renders, id) = button(gate: .cancelPrevious) {
            runs += 1
            if runs == 1 { ticker.start() }
            await latch.wait()
        }

        renders.fire(id)
        renders.fire(id)
        let before = ticked.wrappedValue
        try await waitUntil { ticked.wrappedValue >= before + 3 }
        ticker.stop()
        latch.open()

        XCTAssertGreaterThanOrEqual(ticked.wrappedValue, before + 3, "the ticks' writes were refused as the superseded run's")
    }

    /// Two handlers of one event keep their own runs, each by its own word.
    func testEachHandlerOfAnEventKeepsItsOwnRuns() async throws {
        let latch = Latch()
        var ignoring = 0
        var overlapping = 0
        let renders = Renders()
        let patch = renders.render(
            Button("Go")
                .onClicked(gate: .ignoreWhileRunning) {
                    ignoring += 1
                    await latch.wait()
                }
                .onClicked(gate: .none) {
                    overlapping += 1
                    await latch.wait()
                }
                .node)
        let id = try XCTUnwrap(patch.events?["clicked"])

        renders.fire(id)
        renders.fire(id)
        XCTAssertEqual(ignoring, 1)
        XCTAssertEqual(overlapping, 2, "the second handler did not wait for the first")
        latch.open()
    }

    /// A task through a shared gate and a click through it hold each other back: the one that comes while the
    /// other runs is let go.
    func testATaskAndAClickThroughOneGateHoldEachOtherBack() async throws {
        let latch = Latch()
        let document = SharedGate(.ignoreWhileRunning)
        var clicks = 0, saves = 0
        let (renders, id) = button(gate: document) { clicks += 1; await latch.wait() }

        renders.fire(id)
        let ignored = Task(gate: document) { saves += 1 }
        await ignored.value
        XCTAssertEqual([clicks, saves], [1, 0], "the task came while the click's run was under way")

        latch.open()
        try await waitUntil { !document.isBusy }
        Task(gate: document) { saves += 1; await latch.wait() }
        renders.fire(id)
        XCTAssertEqual([clicks, saves], [1, 1], "the click came while the task's run was under way")
        XCTAssertTrue(document.isBusy, "a task's run makes the gate busy")

        latch.open()
        try await waitUntil { !document.isBusy }
    }

    /// A task's value is its run's end: awaiting it waits until the work is done.
    func testATasksValueWaitsForItsRun() async throws {
        let latch = Latch()
        let gate = SharedGate(.none)
        let landed = State(wrappedValue: 0)

        let task = Task(gate: gate) {
            await latch.wait()
            landed.wrappedValue = 1
        }
        XCTAssertEqual(landed.wrappedValue, 0)

        latch.open()
        await task.value
        XCTAssertEqual(landed.wrappedValue, 1, "the value came before the run's write")
        XCTAssertFalse(gate.isBusy)
    }

    /// Cancelling a task supersedes its run: it changes nothing from then on, and the gate is free again.
    func testCancellingATaskSupersedesItsRun() async throws {
        let latch = Latch()
        let gate = SharedGate(.ignoreWhileRunning)
        let landed = State(wrappedValue: 0)
        var cancelled = false

        let task = Task(gate: gate) {
            await latch.wait()
            cancelled = Task.isCancelled
            landed.wrappedValue = 1
        }
        task.cancel()
        latch.open()
        await task.value
        await settle()

        XCTAssertTrue(cancelled, "the run's task was not cancelled")
        XCTAssertEqual(landed.wrappedValue, 0, "the cancelled run's write was let through")
        XCTAssertFalse(gate.isBusy)
    }

    /// A task cancelled while it waits its turn leaves the queue at once: it ends unrun, and stops holding the gate
    /// and the count of runs under way.
    func testATaskCancelledWhileWaitingLeavesTheQueueAtOnce() async throws {
        let latch = Latch()
        let queue = SharedGate(.waitForPrevious)
        let before = HostBoundary.tally.runs
        var ran = 0
        let first = Task(gate: queue) { await latch.wait() }
        let second = Task(gate: queue) { ran += 1 }
        XCTAssertEqual(HostBoundary.tally.runs, before + 2)

        second.cancel()
        var ended = false
        Task { await second.value; ended = true }
        try await waitUntil { ended }
        XCTAssertEqual(ran, 0, "the cancelled task's work ran")
        XCTAssertEqual(HostBoundary.tally.runs, before + 1, "the cancelled task still counts")
        XCTAssertTrue(queue.isBusy, "the first run still holds the gate")

        latch.open()
        await first.value
        XCTAssertFalse(queue.isBusy)
    }

    /// A task through a gate that cancels the previous run cancels a click's run under way through it.
    func testATaskCancelsTheRunBeforeItThroughItsGate() async throws {
        let latch = Latch()
        let search = SharedGate(.cancelPrevious)
        let found = State(wrappedValue: "")
        let (renders, id) = button(gate: search) {
            await latch.wait()
            found.wrappedValue = "clicked"
        }

        renders.fire(id)
        let task = Task(gate: search) { found.wrappedValue = "task" }
        await task.value
        latch.open()
        try await waitUntil { latch.waiting == 0 && !search.isBusy }
        await settle()

        XCTAssertEqual(found.wrappedValue, "task", "the click's late write overwrote the task's")
    }

    /// Tasks through a gate that waits run one after another, in the order they were started, and the gate is busy
    /// while one waits.
    func testTasksThroughAWaitingGateRunInTheirOrder() async throws {
        let latch = Latch()
        let queue = SharedGate(.waitForPrevious)
        var started: [Int] = []

        let tasks = (1...3).map { number in
            Task(gate: queue) {
                started.append(number)
                await latch.wait()
            }
        }
        XCTAssertEqual(started, [1], "one runs, two wait")

        for expected in [[1, 2], [1, 2, 3]] {
            latch.open()
            try await waitUntil { started == expected }
            XCTAssertTrue(queue.isBusy)
        }
        latch.open()
        for task in tasks { await task.value }
        XCTAssertFalse(queue.isBusy)
    }

    /// A task a handler starts through a shared gate belongs to the gate, not to the handler's run: the element
    /// leaving supersedes the handler's run, and the task goes on to its end.
    func testATaskAHandlerStartsBelongsToTheGate() async throws {
        let latch = Latch()
        let document = SharedGate(.none)
        let saved = State(wrappedValue: 0), said = State(wrappedValue: 0)
        let (renders, id) = button(gate: .none) {
            Task(gate: document) {
                await latch.wait()
                saved.wrappedValue = 1
            }
            await latch.wait()
            said.wrappedValue = 1
        }

        renders.fire(id)
        renders.render(Text("gone").node)
        latch.open()
        try await waitUntil { !document.isBusy && latch.waiting == 0 }
        await settle()

        XCTAssertEqual(saved.wrappedValue, 1, "the gate's task was superseded with the handler's run")
        XCTAssertEqual(said.wrappedValue, 0, "the handler's run outlived its element")
    }

    /// A run waiting its turn whose element leaves never starts, and its task ends: nothing is left under way, and
    /// nothing keeps its handler.
    func testAWaitingRunWhoseElementLeftEnds() async throws {
        let latch = Latch()
        let before = HostBoundary.tally.runs
        var started = 0
        var token: Token? = Token()
        weak let kept = token
        let (renders, id) = button(gate: .waitForPrevious) { [token] in
            _ = token
            started += 1
            await latch.wait()
        }
        token = nil

        renders.fire(id)
        renders.fire(id)
        renders.render(Text("gone").node)
        latch.open()
        try await waitUntil { HostBoundary.tally.runs == before }
        await settle()

        XCTAssertEqual(started, 1, "the waiting run started after its element left")
        XCTAssertNil(kept, "a task of the waiting run never ended and keeps its handler")
    }

    /// A gate nobody holds is freed once its runs end - whoever passed through it, a click or a task.
    func testAGateNobodyHoldsIsFreed() async throws {
        let latch = Latch()
        weak var gone: SharedGate?
        let renders = Renders()

        do {
            let gate = SharedGate(.ignoreWhileRunning)
            gone = gate
            let id = renders.render(Button("Go").onClicked(gate: gate) { await latch.wait() }.node)
                .events?["clicked"] ?? -1
            renders.fire(id)
            let task = Task(gate: gate) {}
            await task.value
            latch.open()
            try await waitUntil { !gate.isBusy }
        }
        renders.render(Text("gone").node)
        await settle()

        XCTAssertNil(gone, "something kept the gate after its element left and its runs ended")
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
        let latch = Latch()
        let count = State(wrappedValue: 0)
        count.storage.origin = "countGone"
        let (renders, id) = button(gate: .none) {
            let seen = count.wrappedValue
            await latch.wait()
            count.wrappedValue = seen + 1
        }

        renders.fire(id)
        count.wrappedValue = 10
        latch.open()
        try await waitUntil { count.wrappedValue == 1 }

        XCTAssertTrue(hasComplained("`countGone` was written by a handler that read it before an `await`"))
    }

    /// Reading the state again after the `await` builds on what it is: nothing is said.
    func testAWriteAfterReadingAgainSaysNothing() async throws {
        let latch = Latch()
        let count = State(wrappedValue: 0)
        count.storage.origin = "countReadAgain"
        let (renders, id) = button(gate: .none) {
            _ = count.wrappedValue
            await latch.wait()
            count.wrappedValue += 1
        }

        renders.fire(id)
        count.wrappedValue = 10
        latch.open()
        try await waitUntil { count.wrappedValue == 11 }

        XCTAssertFalse(hasComplained("`countReadAgain`"))
    }

    /// A value read before an `await` that nobody wrote meanwhile is still what it was: nothing is said.
    func testAWriteOnAValueNobodyChangedSaysNothing() async throws {
        let latch = Latch()
        let count = State(wrappedValue: 0)
        count.storage.origin = "countKept"
        let (renders, id) = button(gate: .none) {
            let seen = count.wrappedValue
            await latch.wait()
            count.wrappedValue = seen + 1
        }

        renders.fire(id)
        latch.open()
        try await waitUntil { count.wrappedValue == 1 }

        XCTAssertFalse(hasComplained("`countKept`"))
    }

    /// Two buttons side by side, rendered, and each one's click.
    private func twoButtons(_ first: Button, _ second: Button) -> (Renders, Int, Int) {
        let renders = Renders()
        let ids = clickedIds(in: renders.render(HStack { first; second }.node))
        return (renders, ids[0], ids[1])
    }

    /// Every click a patch hears, in the order its buttons stand.
    private func clickedIds(in patch: HostPatch) -> [Int] {
        var ids: [Int] = []
        func walk(_ node: HostPatch) {
            if let id = node.events?["clicked"] { ids.append(id) }
            node.children.forEach(walk)
        }
        walk(patch)
        return ids
    }

    /// A button whose click runs `handler` through `gate`, rendered, and its click's id.
    private func button(
        gate: some Gate, _ handler: @escaping EventHandler
    ) -> (Renders, Int) {
        let renders = Renders()
        let patch = renders.render(Button("Go").onClicked(gate: gate, handler).node)
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

/// An element with events enough for an order among them to show.
private enum ChimesContract: ElementContract {
    static let nodeType: NodeType = "Test.Chimes"

    static let events = (0..<8).map { ElementEvent<Self, Void>("chime\($0)") }

    static let members: [any ContractMember] = events
}

/// The element `ChimesContract` declares.
private struct Chimes: ElementView {
    var node = Node(contract: ChimesContract.self)
}

/// Something a handler holds, whose release says nothing holds the handler any more.
private final class Token {}

/// Where a handler waits until the test lets it go.
@MainActor
private final class Latch {
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
