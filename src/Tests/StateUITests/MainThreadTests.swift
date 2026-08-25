// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Where a handler runs, and where it comes back.
//
// This is the one part of the library whose failure is silent. A handler that
// resumes on the wrong thread writes state beside a C# render and nothing
// crashes reliably - which is why the executor exists at all, and why what it
// promises is written down here rather than remembered.
//
// What a headless test CAN show: that a handler which never awaits finishes
// inside the call that raised it, that one which does await does not, and that
// every async function in the library is declared so that it stays on its
// caller's executor. What it cannot show is the thread itself - there is no host
// here, so there is only one thread to be on. That part was measured against a
// running app.

import Foundation
import XCTest
@testable import StateUI

final class MainThreadTests: XCTestCase {
    // MARK: - The waker

    /// A handler may await something that is NOT a host command - `Task.sleep`,
    /// a task's value - because a job landing in the queue wakes the thread the
    /// host keeps parked in `stateui_wait_work`.
    ///
    /// The sleep below comes due on the runtime's own timer with no
    /// command in flight, and its resume still reaches the queue promptly
    /// because the park is released. The worker thread stands in for the
    /// host's, doing exactly what the host's does: park, wake, ask for a drain.
    func testASleepingHandlerIsResumedWithNoCommandInFlight() throws {
        let renders = Renders()
        nonisolated(unsafe) var woke = false

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

        // The host's parked thread, stood in for: park until the queue has the
        // resume in it. Each turn of the loop PARKS - `stateui_wait_work`
        // blocks until something pokes - and what is being waited for here is a
        // JOB, because the waker also announces a dirty tree and one may be
        // left over from another test.
        let parked = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            while MainThreadExecutor.shared.pendingCount == 0 {
                _ = stateui_wait_work()
            }

            parked.signal()
        }

        XCTAssertEqual(
            parked.wait(timeout: .now() + 5), .success,
            "the sleep came due and nothing woke the parked thread")

        stateUIRunJobs()
        XCTAssertTrue(woke, "the resume was in the queue the wake announced")
    }

    /// An act queued from a plain `Task` - the pool, no handler suspended on
    /// it, no job on the executor - still wakes the parked thread: `send`
    /// pokes it, and the count `stateui_wait_work` returns includes the
    /// queued COMMANDS, so the host drains and takes the act.
    ///
    /// Without the poke this was the gallery's press animation frozen at its
    /// dip: the return half was queued from the press Task at the moment the
    /// dip completed, nothing announced it, and the card stayed pressed until
    /// the next event reached the app - on Android, forever.
    func testACommandQueuedFromAPlainTaskWakesTheParkedThread() throws {
        _ = Renderer.shared.takeCommandsWire()

        let parked = DispatchSemaphore(value: 0)

        DispatchQueue.global().async {
            // WAITS FOR THE WORK, not for a wake - the shape the sleeping test
            // above uses, and this one only claimed to. `stateui_wait_work`
            // is fed by a counting semaphore, so a wake another test left
            // behind returns from it at once with nothing queued; exiting on
            // THAT signalled the main thread before the detached Task had
            // sent, and the act was asserted for before it existed. Measured
            // as roughly one full-suite run in two, and never alone.
            //
            // The wake is still what is being proved: with nothing poking it
            // this blocks, and the five-second wait below is what fails.
            while Renderer.shared.commandsPending == 0 {
                _ = stateui_wait_work()
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
            dispatch returns. The host renders and drains the command queue \
            straight afterwards, so anything left unfinished would be shown one \
            event late.
            """)
    }

    /// And the other half: a handler that awaits gives up the thread, which is
    /// the entire point and the entire risk.
    func testAHandlerThatAwaitsGivesTheThreadBackBeforeItFinishes() async throws {
        let renders = Renders()
        var reached = false

        _ = Renderer.shared.takeCommandsWire()

        let patch = renders.render(
            Button("Go")
                .onClicked {
                    try await Dialogs.displayAlert("//list", message: "saved")
                    reached = true
                }
                .body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        XCTAssertFalse(reached, "the handler is suspended, waiting for the host")

        let acts = drainedActs()
        XCTAssertEqual(acts.first?.name, "displayAlertAsync")

        // What the host does when the navigation is over.
        let completion = try XCTUnwrap(acts.compactMap(\.completion).first)

        ReplyBuffer.current = .finished([])
        XCTAssertTrue(Renderer.shared.dispatch(completion))
        await settle()

        // The resumed job is handed to whoever can run it, which takes a moment
        // - measured: `resume()` returns before the job exists. In an app that
        // moment is one turn of the UI thread.
        try await waitUntil { reached }
        XCTAssertTrue(reached, "the rest of the handler never ran")
    }

    /// An error out of a handler is reported rather than lost, so a failed
    /// `try await` is something an author can see.
    func testAHandlerThatThrowsIsReportedToTheHost() async throws {
        let renders = Renders()

        _ = Renderer.shared.takeCommandsWire()

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
    /// executor, or on `@MainThread`.
    ///
    /// A plain `async` function is nonisolated, and a nonisolated async function
    /// runs on Swift's cooperative pool whoever calls it - so a handler awaiting
    /// one would come back on a pool thread with a C# render beside it. The
    /// spelling that prevents it is `nonisolated(nonsending)`. The other
    /// spelling that does is `@MainThread`, which names the executor outright
    /// and makes a caller from the pool hop there first - what `Renderer.fly`
    /// does, so that a flight is booked and committed on the rendering
    /// thread whoever started it.
    ///
    /// This is not hypothetical: an early act was written without it, and what
    /// showed was not a crash but a command queue that filled up a moment late.
    /// A regex over sources is acceptable here for the reason it is in
    /// DocumentationTests - it is a test reading the library beside it, and a
    /// signature it fails to recognize is one nobody is asked to annotate.
    func testEveryAsyncFunctionRunsOnItsCallersExecutor() throws {
        var unmarked: [String] = []

        for source in try Fixtures.allSources() {
            let lines = source.text.components(separatedBy: "\n")

            for (index, line) in lines.enumerated() {
                guard declaresAnAsyncFunction(line) else { continue }

                // The marker may be on this line or on the `func` line above,
                // when the signature is spread over several. Comments are left
                // out on purpose: the doc comment above such a function often
                // EXPLAINS the marker, and reading that as the marker itself is
                // a false pass - which is exactly what this check did first
                // time, and why it is verified by removing a real one.
                let window = lines[max(0, index - 8)...index]
                    .filter { !$0.trimmed.hasPrefix("//") }
                    .joined(separator: " ")

                if !window.contains("nonisolated(nonsending)") && !window.contains("@MainThread func") {
                    unmarked.append("\(source.path):\(index + 1)  \(line.trimmed)")
                }
            }
        }

        XCTAssertEqual(unmarked, [], """
            These are async and do not say where they run:

            \(unmarked.joined(separator: "\n"))

            Write `nonisolated(nonsending)` before `func` - or `@MainThread`, \
            when the function must run on the rendering thread whoever calls \
            it. Without either the function runs on Swift's cooperative pool, \
            and a handler that awaits it resumes off the thread MAUI draws on \
            - which corrupts state quietly rather than failing. See \
            Core/MainThread.swift.
            """)
    }

    /// And the same rule for the code this library cannot annotate.
    ///
    /// `nonisolated(nonsending)` is a spelling, so it only ever covers the six
    /// functions here that say it. An application's own `async func` is beyond
    /// reach - and measured, it is exactly where the rule breaks: a helper an
    /// author writes and awaits from a handler runs on the cooperative pool and
    /// comes back off the thread MAUI draws on, with no diagnostic anywhere.
    ///
    /// The upcoming feature makes caller-inheriting the DEFAULT, which closes
    /// that. It is per-module, so it has to be set in every manifest and in both
    /// build scripts - Apple and Windows call swiftc directly and would
    /// otherwise compile the same sources with different defaults from Android.
    /// That spread is the reason this is a test: missing one of them costs
    /// nothing at build time and everything at run time.
    ///
    /// Every application's manifest is FOUND rather than listed, so a scaffolded
    /// app is covered the moment it exists - including the one `dotnet new`
    /// writes, whose template manifest is checked here too.
    /// THE FOUR NON-NEGOTIABLES, checked instead of remembered - CONTRIBUTING.md
    /// states them, under "The rules a pull request is measured against". Every
    /// one of them breaks a platform silently and far from the cause, which is
    /// why they are rules rather than preferences, and why a test pins them.
    ///
    /// - **The LIBRARY never imports Foundation.** `Core/Wire.swift` writes the
    ///   wire by hand and a date on it is three integers. An application may
    ///   import it; nothing under `Sources/` may.
    /// - **`@MainActor` is banned**, everywhere. It is libdispatch's main
    ///   queue, which nothing drains on Android or Windows. This library's own
    ///   global actor is `@MainThread`.
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
            ("@MainActor",
             "@MainActor is libdispatch's main queue, which nothing drains on Android "
                + "or Windows - this library's actor is @MainThread"),
            ("Timer",
             "a Foundation Timer hangs off a run loop nothing turns - a timer here is "
                + "Task.sleep and the waker in Core/Ticker.swift"),
            ("RunLoop",
             "a RunLoop is drained by nothing on Android or Windows"),
            ("strdup",
             "memory allocated in Swift is freed in Swift - strdup/free mixes allocators "
                + "and crashes on Windows"),
        ]

        var broken: [String] = []

        for source in try Fixtures.allSources() {
            let code = MainThreadTests.withoutComments(source.text)

            for rule in banned where code.contains(rule.needle) {
                broken.append("\(source.path) uses \(rule.needle) - \(rule.why)")
            }
        }

        XCTAssertEqual(broken, [], """
            The library broke one of its non-negotiables:

            \(broken.joined(separator: "\n"))

            Each of these breaks one platform while the others go on working. \
            See CONTRIBUTING.md, "The rules a pull request is measured against".
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
            "src/Tests/Package.swift",
            ".scripts/build-apple.sh",
            ".scripts/build-windows.ps1",
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
            the thread MAUI draws on. See Core/MainThread.swift.
            """)
    }

    // MARK: - Support

    /// Every application manifest in the repository, relative to its root: the
    /// ones under apps/, and the one `dotnet new` writes an app from.
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

        found.append("src/StateUI.Template/templates/StateUIStarter/Package.swift")
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
    /// the thread MAUI draws on with it.
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
        final class Countdown: @unchecked Sendable { var left = 200 }
        let countdown = Countdown()

        // Queued from INSIDE the running job, which is what puts it on the
        // very next pass.
        @Sendable func again() async throws {
            countdown.left -= 1
            if countdown.left > 0 { Renderer.shared.queue(again) }
        }

        Renderer.shared.queue(again)

        let deadline = Date().addingTimeInterval(2)
        while MainThreadExecutor.shared.pendingCount == 0, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.002)
        }

        XCTAssertEqual(stateUIRunJobs(), 64, "a drain ran other than its 64 passes")
        XCTAssertGreaterThan(
            MainThreadExecutor.shared.pendingCount, 0,
            "the drain stopped without leaving the rest waiting")

        // And the host asking again is what finishes it - drained here so the
        // next test does not inherit the rest.
        while countdown.left > 0 { _ = stateUIRunJobs() }
        while stateUIRunJobs() > 0 {}
    }

    /// the host is told and puts it on the UI thread; in a test there is nobody
    /// to tell, so the only honest thing is to wait a bounded while.
    private func waitUntil(
        _ condition: () -> Bool,
        timeout: TimeInterval = 2
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)

        while !condition(), Date() < deadline {
            stateUIRunJobs()
            try await Task.sleep(nanoseconds: 200_000)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespaces)
    }
}
