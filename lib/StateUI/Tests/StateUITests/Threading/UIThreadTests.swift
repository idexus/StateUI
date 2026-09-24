// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a handler runs, and where it comes back: MainActor, the host's UI
// thread.
//
// This is the one part of the library whose failure is silent. A handler that
// resumes on the wrong thread writes state while the host is drawing, and one
// that never resumes leaves the interface standing, and nothing crashes
// reliably - which is why what it promises is written down here rather than
// remembered.
//
// What a headless test CAN show: that a handler which never awaits finishes
// inside the call that raised it, that one which does await does not and comes
// back without another event, that a job on the UI thread's queue wakes the
// host, and that every async function in the library is declared so that it
// stays on its caller's executor. A test that stands for the host runs on
// MainActor, as the host calls in on its UI thread. What it cannot show is the
// thread itself - there is no host here. That part was measured against a
// running app on every platform.

import Foundation
import XCTest
@_spi(Host) @testable import StateUI

/// A composed view that reads one state - a live reader of it for as long as
/// the tree that holds it stands.
private struct Shows: ContentView {
    let fade: State<Double>

    var content: any View {
        ModifiedContent(node: label("\(fade.get())"))
    }
}

final class UIThreadTests: XCTestCase {
    // MARK: - The waker

    /// A handler may await something that is NOT a host act - `Task.sleep`,
    /// a task's value - and comes back with no act in flight and no other
    /// event: its resume is MainActor's job, which the UI thread runs.
    @MainActor
    func testASleepingHandlerIsResumedWithNoActInFlight() async throws {
        let renders = Renders()
        var woke = false

        let patch = renders.render(
            Button("Nap")
                .onClicked {
                    try await Task.sleep(nanoseconds: 30_000_000)
                    woke = true
                }
                .body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))
        XCTAssertFalse(woke, "the handler is asleep, and nothing has been reported")

        try await waitUntil { woke }
        XCTAssertTrue(woke, "the sleep came due and the handler never came back")
    }

    /// A job landing on the UI thread's queue wakes the thread the host keeps
    /// parked in `StateUIHost.waitForWork` - which is how MainActor's jobs reach the
    /// UI thread where the host alone drains it. Proved with an actor of this
    /// test's own on that queue, so it holds on every platform, Apple's
    /// included: the worker thread stands in for the host's, doing exactly what
    /// the host's does - park, wake, ask for a drain.
    func testAJobOnTheUIThreadsQueueWakesTheParkedThread() throws {
        let queued = OnTheUIThreadsQueue()

        let parked = DispatchSemaphore(value: 0)

        // Each turn PARKS - `StateUIHost.waitForWork` blocks until something pokes -
        // and what is waited for is a JOB, because the waker also announces a
        // dirty tree and one may be left over from another test.
        DispatchQueue.global().async {
            while UIThreadExecutor.shared.pendingCount == 0 {
                _ = StateUIHost.waitForWork()
            }

            parked.signal()
        }

        Task.detached { await queued.touch() }

        XCTAssertEqual(
            parked.wait(timeout: .now() + 5), .success,
            "a job landed on the UI thread's queue and nothing woke the parked thread")

        stateUIRunJobs()
        XCTAssertEqual(queued.touches, 1, "the job was in the queue the wake announced")
    }

    /// An act queued from a plain `Task` - the pool, no handler suspended on
    /// it, no job on the executor - still wakes the parked thread: `send`
    /// pokes it, and the count `StateUIHost.waitForWork` returns includes the
    /// queued ACTS, so the host drains and takes the act.
    ///
    /// Without the poke this was the gallery's press animation frozen at its
    /// dip: the return half was queued from the press Task at the moment the
    /// dip completed, nothing announced it, and the card stayed pressed until
    /// the next event reached the app - on Android, forever.
    func testAnActQueuedFromAPlainTaskWakesTheParkedThread() throws {
        _ = drainedActs()

        let parked = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            // WAITS FOR THE WORK, not for a wake - the shape the sleeping test
            // above uses, and this one only claimed to. `StateUIHost.waitForWork`
            // is fed by a counting semaphore, so a wake another test left
            // behind returns from it at once with nothing queued; exiting on
            // THAT signalled the main thread before the detached Task had
            // sent, and the act was asserted for before it existed. Measured
            // as roughly one full-suite run in two, and never alone.
            //
            // The wake is still what is being proved: with nothing poking it
            // this blocks, and the five-second wait below is what fails.
            while Renderer.shared.actCallsPending == 0 {
                _ = StateUIHost.waitForWork()
            }

            parked.signal()
        }

        // The pool, as a plain `Task` in a handler is: only the act, no job.
        Task.detached {
            Renderer.shared.send(.focus, [.string("card")], completion: nil)
        }

        XCTAssertEqual(
            parked.wait(timeout: .now() + 5), .success,
            "the queued act woke nobody - the host would not perform it until the next event")

        XCTAssertTrue(
            drainedActs().contains { $0.name == "focus" },
            "the act the wake announced is there to take")
    }

    /// A DIRTY TREE is work, and the WRITE ITSELF is what wakes the host to
    /// count it.
    ///
    /// A write made inside something the host is driving is rendered by the
    /// drain that follows; a write a `Task.detached` makes from the pool has
    /// nothing following it - no job, no act. Two things keep that write
    /// from waiting for the next touch: the dirty flag counts as work in
    /// `StateUIHost.waitForWork`, and `stateChanged` pokes the parked thread AFTER
    /// setting it, so the thread cannot wake, read a clean flag, and park
    /// again with the write behind it. This asks the waker's question with
    /// nothing but the write having happened - `waitForWork` BLOCKS until
    /// something signals, so a write that did not signal would hang here.
    func testAStateWriteAloneWakesTheHostAndReadsAsWork() async throws {
        // Quiet first - and the batch DECODED rather than thrown away, or the
        // names it announced are gone and the next reader dies on them.
        _ = drainedActs()
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()

        // A state SOMETHING READS: a write nobody reads asks for nothing and
        // wakes nobody, by design - see `Renderer.stateChanged` - so the
        // write below is made to a state a live element reads.
        let fade = State(1.0)
        let renders = Renders()
        renders.render(Shows(fade: fade).body)

        // Leave the waker with NO signal pending: a poke is coalesced into
        // one the flag already holds, and one wait collects exactly that one
        // and disarms the flag. From here on, only a new signal can wake it.
        UIThreadExecutor.shared.poke()
        _ = UIThreadExecutor.shared.waitForWork()

        await Task.detached { fade.wrappedValue = 0.5 }.value

        XCTAssertTrue(Renderer.shared.needsRender, "a write dirties the tree")
        XCTAssertEqual(Renderer.shared.actCallsPending, 0, "and queues no act")
        XCTAssertEqual(UIThreadExecutor.shared.pendingCount, 0, "and lands no job")

        XCTAssertGreaterThan(
            StateUIHost.waitForWork(), 0,
            "a dirty tree with no job and no act must read as work, and the "
                + "write alone must have woken the thread that asks")
    }

    /// A KEPT state's write wakes the host even where nobody reads the state:
    /// the save it recorded is work the host must take, and a write to state
    /// nobody reads asks for no render to carry it - so the write wakes the
    /// thread itself, and what is waiting to be saved counts as pending work.
    func testAKeptStateWriteNobodyReadsStillWakesTheHost() async throws {
        _ = drainedActs()
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()

        let key = PersistentKey("mainThread.kept", of: Double.self)
        let kept = State(wrappedValue: 1.0, persistentKey: key)

        UIThreadExecutor.shared.poke()
        _ = UIThreadExecutor.shared.waitForWork()

        await Task.detached { kept.wrappedValue = 0.5 }.value

        XCTAssertFalse(Renderer.shared.needsRender, "nobody reads it, so no render was asked for")
        XCTAssertGreaterThan(Renderer.shared.actCallsPending, 0, "but the save is pending work")
        XCTAssertGreaterThan(
            StateUIHost.waitForWork(), 0,
            "and the write alone woke the thread that asks")

        let acts = drainedActs()
        XCTAssertEqual(acts.map { $0.name }, ["persistValue"], "which then takes the save")
    }

    /// A MOVEMENT started from the pool wakes the host, and what it wrote
    /// reads as work.
    ///
    /// `move(to:)` books its waiter and writes the destination onto the
    /// value's board: no job, no act, and no render where nobody reads the
    /// value. The write waiting for a cycle is the work - counted by
    /// `StateUIHost.waitForWork`, and announced after it lands, so the thread cannot
    /// wake, count nothing and park again with the movement behind it. That
    /// was the gallery's analog clock on the MAUI heads: its `async let`
    /// hands started from the pool, and the clock stood on its first second
    /// until the next event reached the app.
    func testAMovementStartedFromThePoolWakesTheHostAndReadsAsWork() async throws {
        let fade = wornOnAQuietBoard()

        // The id the movement will book is the one after this one, answered
        // below the way a host answers an arrival.
        let before = Renderer.shared.book { _ in }
        _ = Renderer.shared.dispatch(before)

        let work = waitedFor {
            _ = Task.detached {
                try await fade.projectedValue.journey.move(to: 0.1, .eased(400, .cubicOut))
            }
        }

        XCTAssertNotNil(work, "the movement woke nobody - the host would not start it until the next event")
        XCTAssertGreaterThan(
            work ?? 0, 0,
            "a movement with no job, no act and no render must read as work")

        ReplyBuffer.current = .finished([.bool(true)])
        XCTAssertTrue(Renderer.shared.dispatch(before - 1), "the movement booked the next waiter")
    }

    /// A value the host carries, written from the pool where nobody reads it,
    /// wakes the host - the write waits on its board for a cycle, which is
    /// work even where no render is asked for.
    func testACarriedWriteFromThePoolWakesTheHostAndReadsAsWork() async throws {
        let fade = wornOnAQuietBoard()

        let work = waitedFor {
            Task.detached { fade.wrappedValue = 0.5 }
        }

        XCTAssertNotNil(work, "the write woke nobody - the host would not carry it until the next event")
        XCTAssertFalse(Renderer.shared.needsRender, "nobody reads it, so no render was asked for")
        XCTAssertGreaterThan(work ?? 0, 0, "and what waits on its board is work")
    }

    /// What the host's parked thread counts once `start` has run, or nil where
    /// nothing woke it within five seconds.
    ///
    /// The waker is left with no signal pending first, so only what `start`
    /// does can wake it; the thread is parked before `start` runs, as the
    /// host's always is. A thread nothing woke stays parked when this returns
    /// nil, and takes the next wake the suite makes - the failure is already
    /// said by then.
    private func waitedFor(_ start: () -> Void) -> Int? {
        UIThreadExecutor.shared.poke()
        _ = UIThreadExecutor.shared.waitForWork()

        let counted = DispatchSemaphore(value: 0)
        nonisolated(unsafe) var work = 0

        DispatchQueue.global().async {
            work = StateUIHost.waitForWork()
            counted.signal()
        }

        start()

        return counted.wait(timeout: .now() + 5) == .success ? work : nil
    }

    /// A state a rendered view wears as a driven property, on a board with
    /// nothing waiting and nothing queued anywhere else.
    private func wornOnAQuietBoard() -> State<Double> {
        _ = drainedActs()
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()

        let fade = State(wrappedValue: 1.0)
        Renders().render(Label("worn").opacity(fade.projectedValue).id("worn").body)

        _ = StateUIHost.cycle(.display, now: 0, reducesMotion: false)
        Renderer.shared.clearInvalidation()

        XCTAssertNotNil(fade.number, "the view wears the state")
        XCTAssertEqual(Renderer.shared.cycleAwake(), 0, "and its board has nothing waiting")

        return fade
    }

    // MARK: - What a dispatch promises

    /// The compatibility guarantee: making handlers asynchronous must not make
    /// the ordinary ones later.
    func testAHandlerThatNeverAwaitsFinishesInsideTheDispatch() throws {
        let renders = Renders()
        var taps = 0

        let patch = renders.render(Button("Tap").onClicked { taps += 1 }.body)
        let id = try XCTUnwrap(patch.events?["clicked"])

        XCTAssertTrue(renders.fire(id))

        XCTAssertEqual(taps, 1, """
            A handler with no suspension in it has to run to completion before \
            dispatch returns. The host renders and drains the act queue \
            straight afterwards, so anything left unfinished would be shown one \
            event late.
            """)
    }

    /// And the other half: a handler that awaits gives up the thread, which is
    /// the entire point and the entire risk.
    @MainActor
    func testAHandlerThatAwaitsGivesTheThreadBackBeforeItFinishes() async throws {
        let renders = Renders()
        var reached = false

        _ = drainedActs()

        let patch = renders.render(
            Button("Go")
                .onClicked {
                    try await Dialogs.alert("//list", message: "saved")
                    reached = true
                }
                .body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        XCTAssertFalse(reached, "the handler is suspended, waiting for the host")

        let acts = drainedActs()
        XCTAssertEqual(acts.first?.name, "alert")

        // What the host does when the navigation is over.
        let completion = try XCTUnwrap(acts.compactMap(\.completion).first)

        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(completion))
        await settle()

        // The resumed job is MainActor's, which takes a moment - measured:
        // `resume()` returns before the job exists. In an app that moment is
        // one turn of the UI thread.
        try await waitUntil { reached }
        XCTAssertTrue(reached, "the rest of the handler never ran")
    }

    /// An error out of a handler is reported rather than lost, so a failed
    /// `try await` is something an author can see.
    @MainActor
    func testAHandlerThatThrowsIsReportedToTheHost() async throws {
        let renders = Renders()

        _ = drainedActs()

        let patch = renders.render(
            Button("Break")
                .onClicked { throw StateUIError(message: "no route") }
                .body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        let acts = drainedActs()
        XCTAssertEqual(acts.first?.name, "handlerFailed")
        XCTAssertEqual(acts.first?.arguments.first, .string("no route"))
    }

    // MARK: - The rule that keeps it true

    /// Every async function here must SAY where it runs: on its caller's
    /// executor, or on `@MainActor`.
    ///
    /// A plain `async` function is nonisolated, and a nonisolated async function
    /// runs on Swift's cooperative pool whoever calls it - so a handler awaiting
    /// one would come back on a pool thread with the host drawing beside it.
    /// The spelling that prevents it is `nonisolated(nonsending)`. The other
    /// spelling that does is `@MainActor`, which names the UI thread outright
    /// and makes a caller from the pool hop there first.
    ///
    /// This is not hypothetical: an early act was written without it, and what
    /// showed was not a crash but an act queue that filled up a moment late.
    /// A regex over sources is acceptable here for the reason it is in
    /// DocumentationTests - it is a test reading the library beside it, and a
    /// signature it fails to recognize is one nobody is asked to annotate.
    func testEveryAsyncFunctionRunsOnItsCallersExecutor() throws {
        var unmarked: [String] = []
        var read = 0

        for source in try Fixtures.allSources() {
            let lines = source.text.components(separatedBy: "\n")

            for (index, line) in lines.enumerated() {
                guard declaresAnAsyncFunction(line) else { continue }

                read += 1

                // The marker may be on this line or on the `func` line above,
                // when the signature is spread over several. Comments are left
                // out on purpose: the doc comment above such a function often
                // EXPLAINS the marker, and reading that as the marker itself is
                // a false pass - which is exactly what this check did first
                // time, and why it is verified by removing a real one.
                let window = lines[max(0, index - 8)...index]
                    .filter { !$0.trimmed.hasPrefix("//") }
                    .joined(separator: " ")

                if !window.contains("nonisolated(nonsending)") && !window.contains("@MainActor func") {
                    unmarked.append("\(source.path):\(index + 1)  \(line.trimmed)")
                }
            }
        }

        XCTAssertGreaterThan(read, 19, "the scan read almost nothing")
        XCTAssertEqual(unmarked, [], """
            These are async and do not say where they run:

            \(unmarked.joined(separator: "\n"))

            Write `nonisolated(nonsending)` before `func` - or `@MainActor`, \
            when the function must run on the rendering thread whoever calls \
            it. Without either the function runs on Swift's cooperative pool, \
            and a handler that awaits it resumes off the thread the host draws on \
            - which corrupts state quietly rather than failing. See \
            UIThread.swift.
            """)
    }

    /// And the same rule for the code this library cannot annotate.
    ///
    /// `nonisolated(nonsending)` is a spelling, so it only ever covers the six
    /// functions here that say it. An application's own `async func` is beyond
    /// reach - and measured, it is exactly where the rule breaks: a helper an
    /// author writes and awaits from a handler runs on the cooperative pool and
    /// comes back off the thread the host draws on, with no diagnostic anywhere.
    ///
    /// The upcoming feature makes caller-inheriting the DEFAULT, which closes
    /// that. It is per-module, so it has to be set in every manifest and in both
    /// build scripts - Apple and Windows call swiftc directly and would
    /// otherwise compile the same sources with different defaults from Android.
    /// That spread is the reason this is a test: missing one of them costs
    /// nothing at build time and everything at run time.
    ///
    /// Every application's manifest is FOUND rather than listed, so a scaffolded
    /// app is covered the moment it exists.
    /// THE FOUR NON-NEGOTIABLES, checked instead of remembered - CONTRIBUTING.md
    /// states them, under "Keep the core platform-neutral". Every
    /// one of them breaks a platform silently and far from the cause, which is
    /// why they are rules rather than preferences, and why a test pins them.
    ///
    /// - **The LIBRARY never imports Foundation.** `Wire.swift` writes the
    ///   wire by hand and a date on it is three integers. An application may
    ///   import it; nothing under `Sources/` may.
    /// - **`DispatchQueue.main` is banned**, but for the one drain
    ///   UIThread.swift posts there. Nothing drains that queue on Android
    ///   or Windows; MainActor, which the UI thread's own executor serves
    ///   there, is where work for the UI thread goes.
    /// - **`Timer` and `RunLoop` are banned**, for the same reason: they hang
    ///   off a run loop nothing turns. A timer here is `Task.sleep` and the
    ///   waker.
    /// - **Memory allocated in Swift is freed in Swift** - `allocate`/
    ///   `deallocate`, never `strdup`/`free`. Mixing allocators across the
    ///   boundary crashes unpredictably on Windows, where several C runtime
    ///   copies can coexist.
    ///
    /// Comments are stripped first: every one of these words appears in the
    /// sources already, in the comment explaining why it is not used, and
    /// reading that as a violation is a test that cries every time somebody
    /// writes down a reason.
    func testTheLibraryKeepsItsFourNonNegotiables() throws {
        let banned: [(needle: String, why: String)] = [
            ("import Foundation",
             "the library never imports Foundation - Wire.swift writes the wire by hand"),
            ("DispatchQueue.main",
             "nothing drains libdispatch's main queue on Android or Windows - work for "
                + "the UI thread goes to MainActor"),
            ("Timer",
             "a Foundation Timer hangs off a run loop nothing turns - a timer here is "
                + "Task.sleep and the waker in Ticker.swift"),
            ("RunLoop",
             "a RunLoop is drained by nothing on Android or Windows"),
            ("strdup",
             "memory allocated in Swift is freed in Swift - strdup/free mixes allocators "
                + "and crashes on Windows"),
        ]

        var broken: [String] = []

        for source in try Fixtures.allSources() {
            let code = UIThreadTests.withoutComments(source.text)

            for rule in banned where code.contains(rule.needle) {
                // The one post of MainActor's drain to that queue, for wherever
                // something turns it.
                if rule.needle == "DispatchQueue.main", source.path.hasSuffix("/UIThread.swift") {
                    continue
                }

                broken.append("\(source.path) uses \(rule.needle) - \(rule.why)")
            }
        }

        XCTAssertEqual(broken, [], """
            The library broke one of its non-negotiables:

            \(broken.joined(separator: "\n"))

            Each of these breaks one platform while the others go on working. \
            See CONTRIBUTING.md, "Keep the core platform-neutral".
            """)
    }

    /// Source with every comment taken out, so a rule's own explanation is not
    /// read as a breach of it. Line comments and block comments both, and
    /// string literals are left alone - a banned word inside a message is text,
    /// not code, but it is also not a comment.
    private static func withoutComments(_ text: String) -> String {
        var out = ""
        var rest = Substring(text)

        while let character = rest.first {
            if rest.hasPrefix("//") {
                rest = rest.drop(while: { $0 != "\n" })
                continue
            }

            if rest.hasPrefix("/*") {
                rest = rest.dropFirst(2)

                while !rest.isEmpty, !rest.hasPrefix("*/") {
                    rest = rest.dropFirst()
                }

                rest = rest.dropFirst(2)
                continue
            }

            out.append(character)
            rest = rest.dropFirst()
        }

        return out
    }

    func testEverywhereSwiftIsCompiledInheritsTheCallersExecutor() throws {
        var places = [
            "Package.swift",
            "lib/StateUI.AppKit/Package.swift",
        ]

        for app in try appManifests() {
            places.append(app)
        }

        var missing: [String] = []

        for place in places {
            let file = Fixtures.repository.appendingPathComponent(place)
            let text = try String(contentsOf: file, encoding: .utf8)

            if !text.contains("NonisolatedNonsendingByDefault") {
                missing.append(place)
                continue
            }

            // ONE PER TARGET, not one per file. A manifest declaring three
            // targets and marking two reads as covered to a `contains`, and the
            // unmarked target is the one whose handlers land off the executor.
            let targets = ["\n        .target(", "\n        .testTarget(", "\n        .macro("]
                .map { text.components(separatedBy: $0).count - 1 }
                .reduce(0, +)
            let marked = text.components(separatedBy: "NonisolatedNonsendingByDefault").count - 1

            if targets > marked {
                missing.append("\(place) - \(targets) targets, \(marked) marked")
            }
        }

        XCTAssertEqual(missing, [], """
            These compile Swift without NonisolatedNonsendingByDefault:

            \(missing.joined(separator: "\n"))

            A manifest wants \
            `swiftSettings: [.enableUpcomingFeature("NonisolatedNonsendingByDefault")]` \
            on the target; a script wants \
            `-enable-upcoming-feature NonisolatedNonsendingByDefault` on the \
            swiftc line. Without it a plain `async` function written there runs \
            on Swift's cooperative pool, and a handler awaiting one resumes off \
            the executor its native host draws on. See UIThread.swift.
            """)
    }

    // MARK: - Support

    /// Every active application manifest in the repository, relative to its
    /// root.
    private func appManifests() throws -> [String] {
        var found: [String] = []

        let apps = Fixtures.repository.appendingPathComponent("apps")
        for name in try FileManager.default.contentsOfDirectory(atPath: apps.path).sorted()
        where !name.hasPrefix(".") {
            let manifest = "apps/\(name)/Package.swift"
            if FileManager.default.fileExists(
                atPath: Fixtures.repository.appendingPathComponent(manifest).path) {
                found.append(manifest)
            }
        }
        return found
    }

    /// Whether a line declares - or finishes declaring - an async function.
    ///
    /// A closure TYPE is not one of these: a typealias says where the closure
    /// runs at the point it is declared, and the controls all use those aliases.
    private func declaresAnAsyncFunction(_ line: String) -> Bool {
        let text = line.trimmed

        guard text.contains(") async") else { return false }
        guard !text.contains("typealias"), !text.hasPrefix("///"), !text.hasPrefix("//") else {
            return false
        }

        // `(Value) async throws -> Void` in an alias continuation, not a
        // signature of its own.
        return !text.hasSuffix("-> Void")
    }

    /// Waits for something the runtime will do shortly, without a fixed sleep.
    ///
    /// A resumed continuation arrives when the scheduler gets to it. In an app
    /// A drain is BOUNDED, so a job that queues another for ever cannot take
    /// the thread the host draws on with it.
    ///
    /// The loop runs at most 64 passes, each of them everything queued at that
    /// moment - which is what lets a handler that awaits several times finish
    /// inside one drain. The shape that reaches the bound is a job that queues
    /// the NEXT one while it runs, so each pass finds exactly one waiting: the
    /// drain gives back what it ran and leaves the rest pending, and the host
    /// asks again. Without the bound the interface would stop dead with the
    /// process alive and nothing to see.
    ///
    /// A `Task.yield()` loop is NOT that shape and does not reach the bound -
    /// measured, one pass: its continuation is handed back through the global
    /// executor, so the queue is empty again by the time the next pass looks.
    func testADrainIsBoundedSoAJobThatQueuesItselfCannotTakeTheThread() {
        let queued = OnTheUIThreadsQueue()

        // Each job queues the next from INSIDE itself, which is what puts it on
        // the very next pass.
        Task.detached { await queued.countDown(from: 200) }

        let deadline = Date().addingTimeInterval(2)
        while UIThreadExecutor.shared.pendingCount == 0, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.002)
        }

        XCTAssertEqual(stateUIRunJobs(), 64, "a drain ran other than its 64 passes")
        XCTAssertGreaterThan(
            UIThreadExecutor.shared.pendingCount, 0,
            "the drain stopped without leaving the rest waiting")

        // And the host asking again is what finishes it - drained here so the
        // next test does not inherit the rest.
        while queued.left > 0 { _ = stateUIRunJobs() }
        while stateUIRunJobs() > 0 {}
    }

    /// The executor answers WHOSE isolation a thread is in: the UI thread's,
    /// and no other thread's.
    ///
    /// The runtime asks whenever code says it is already where it belongs -
    /// `MainActor.run`, `assumeIsolated`, an `assertIsolated` - and an executor
    /// that does not answer gets the default, which stops the process:
    /// *"Unexpected isolation context, expected to be executing on
    /// UIThreadExecutor"*, thrown on Windows out of the drain the main queue
    /// runs, at the first test of the suite.
    func testTheExecutorAnswersIsolationByTheUIThread() throws {
        // The thread the host drains on is the UI thread, and this test is it.
        stateUIRunJobs()

        XCTAssertEqual(
            UIThreadExecutor.shared.isIsolatingCurrentContext(), true,
            "the UI thread is not in the executor's isolation")

        // A thread of its own: `global().sync` runs its work on the CALLING
        // thread, which is the very thread this is asking about.
        let elsewhere = DispatchSemaphore(value: 0)
        let answered = Asked()

        DispatchQueue.global().async {
            answered.answer = UIThreadExecutor.shared.isIsolatingCurrentContext()
            elsewhere.signal()
        }

        XCTAssertEqual(elsewhere.wait(timeout: .now() + 5), .success)
        XCTAssertEqual(answered.answer, .some(false), "a thread that is not the UI thread was answered as isolated")
    }

    /// And a job the drain runs is in it - which is what the runtime asks about
    /// when a handler resumes.
    func testAJobTheDrainRunsIsInTheExecutorsIsolation() throws {
        let asked = Asks()

        Task.detached { await asked.ask() }

        let deadline = Date().addingTimeInterval(2)
        while UIThreadExecutor.shared.pendingCount == 0, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.002)
        }

        while asked.answer == nil, Date() < deadline { _ = stateUIRunJobs() }

        XCTAssertEqual(asked.answer, true, "a job running on the UI thread was not in the executor's isolation")
    }

    /// What a thread of its own answered.
    private final class Asked: @unchecked Sendable {
        var answer: Bool??
    }

    /// Asks the executor, from a job the executor itself runs.
    private final class Asks: @unchecked Sendable {
        private(set) var answer: Bool?

        func ask() async {
            await OnTheUIThreadsQueue().run { self.answer = UIThreadExecutor.shared.isIsolatingCurrentContext() }
        }
    }

    /// Waits for something the runtime will do shortly, without a fixed sleep:
    /// turns of the UI thread until it holds, for a bounded while. A resumed
    /// continuation arrives when the scheduler gets to it; in an app the host
    /// is told and puts it on the UI thread.
    @MainActor
    private func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 2
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition(), Date() < deadline {
            await settle(timeout: 0)
            try await Task.sleep(nanoseconds: 200_000)
        }
    }
}

/// An actor of this test's own whose jobs wait on the UI thread's queue - where
/// MainActor's wait wherever the host drains that queue - so what the queue
/// does is proved on every platform, Apple's included.
private actor OnTheUIThreadsQueue {
    nonisolated var unownedExecutor: UnownedSerialExecutor {
        UIThreadExecutor.shared.asUnownedSerialExecutor()
    }

    /// How many times `touch` ran.
    nonisolated(unsafe) private(set) var touches = 0

    /// How many jobs `countDown` has left to queue.
    nonisolated(unsafe) private(set) var left = 0

    func touch() {
        touches += 1
    }

    /// Runs `body` on this actor - that is, on the UI thread's queue.
    func run(_ body: () -> Void) {
        body()
    }

    /// Counts down one job at a time, each queued from inside the one before.
    func countDown(from count: Int) {
        left = count - 1
        guard left > 0 else { return }

        Task { countDown(from: left) }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
