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
import Synchronization
import XCTest
@_spi(Host) @testable import StateUI

/// A composed view that reads one state - a live reader of it for as long as
/// the tree that holds it stands.
private struct Shows: View {
    let fade: State<Double>

    var body: some View {
        ModifiedContent(node: label("\(fade.get())"))
    }
}

/// The turns a poster standing for the host's was asked for.
private final class Posts: Sendable {
    let count = Atomic<Int>(0)

    /// Signalled once a turn.
    let asked = DispatchSemaphore(value: 0)

    func post() {
        count.add(1, ordering: .relaxed)
        asked.signal()
    }
}

@MainActor
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
                .onClicked(gate: .none) {
                    try await Task.sleep(nanoseconds: 30_000_000)
                    woke = true
                }
                .node)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))
        XCTAssertFalse(woke, "the handler is asleep, and nothing has been reported")

        try await waitUntil { woke }
        XCTAssertTrue(woke, "the sleep came due and the handler never came back")
    }

    /// A job landing on the UI thread's queue from another thread asks the host
    /// for a turn, on the thread that queued it - which is how MainActor's jobs
    /// reach the UI thread where the host alone drains it. Proved with an actor
    /// of this test's own on that queue, so it holds on every platform, Apple's
    /// included.
    func testAJobFromAnotherThreadAsksForATurn() throws {
        let queued = OnTheUIThreadsQueue()
        let posts = postingTurns()
        defer { stopPostingTurns() }

        Task.detached { await queued.touch() }

        XCTAssertEqual(posts.asked.wait(timeout: .now() + 5), .success, "a job came and the host was asked for no turn")
        XCTAssertEqual(posts.count.load(ordering: .relaxed), 1, "one turn for one job")

        stateUIRunJobs()
        XCTAssertEqual(queued.touches, 1, "the job was in the queue the turn was asked for")
    }

    /// A host that says how to post a turn gets one at once: a job queued before
    /// it said - a task its first render started - is not left for an event.
    func testAHostSayingHowToPostGetsATurnAtOnce() throws {
        let queued = OnTheUIThreadsQueue()
        stateUIRunJobs()
        UIThreadExecutor.shared.postTurns(with: nil)
        Task.detached { await queued.touch() }
        let deadline = Date(timeIntervalSinceNow: 5)
        while UIThreadExecutor.shared.pendingCount == 0, Date() < deadline { Thread.sleep(forTimeInterval: 0.001) }

        let posts = Posts()
        UIThreadExecutor.shared.postTurns(with: { posts.post() })
        defer { stopPostingTurns() }

        XCTAssertEqual(posts.count.load(ordering: .relaxed), 1, "the job queued before waits for an event")
    }

    /// AN ACT SENT asks the host for a turn, so the host takes it with no other
    /// event - and wakes no thread.
    ///
    /// Without the ask this was the gallery's press animation frozen at its
    /// dip: the return half was queued as the dip completed, nothing announced
    /// it, and the card stayed pressed until the next event reached the app -
    /// on Android, forever.
    func testAnActSentAsksForATurn() throws {
        _ = drainedActs()

        let asked = asked { Renderer.shared.send(.focus, [.string("card")], completion: nil) }

        XCTAssertEqual(asked, 1, "the queued act asked for no turn - the host would not perform it until the next event")
        XCTAssertTrue(
            drainedActs().contains { $0.name == "focus" },
            "the act the turn is asked for is there to take")
    }

    /// A STATE WRITE asks the host for a turn on the UI thread's own queue, after
    /// marking the tree dirty.
    func testAStateWriteAsksForATurn() throws {
        _ = drainedActs()
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()

        // A state SOMETHING READS: a write nobody reads asks for nothing, by
        // design - see `Renderer.stateChanged`.
        let fade = State(1.0)
        let renders = Renders()
        renders.render(Shows(fade: fade).node)

        let asked = asked { fade.wrappedValue = 0.5 }

        XCTAssertEqual(asked, 1, "the write asked for no turn")
        XCTAssertTrue(Renderer.shared.needsRender, "a write dirties the tree")
        XCTAssertEqual(Renderer.shared.actCallsPending, 0, "and queues no act")
    }

    /// Changes in a burst ask for ONE turn, and the next change asks again once
    /// that turn's drain has begun - what is changed after it is not lost to a
    /// turn already under way.
    func testABurstAsksForOneTurnUntilItsDrainBegins() throws {
        _ = drainedActs()
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()

        let fade = State(1.0)
        let renders = Renders()
        renders.render(Shows(fade: fade).node)

        let burst = asked {
            fade.wrappedValue = 0.5
            fade.wrappedValue = 0.25
            UIThreadExecutor.shared.askForTurn()
        }
        XCTAssertEqual(burst, 1, "a burst asked for a turn per change")

        let after = asked {
            fade.wrappedValue = 0.5
            stateUIRunJobs()
            fade.wrappedValue = 0.75
        }
        XCTAssertEqual(after, 2, "a change after the drain began asked for no turn of its own")
    }

    /// A KEPT state's write asks for a turn even where nobody reads the state:
    /// the save it recorded is work the host must take, and a write to state
    /// nobody reads asks for no render to carry it.
    func testAKeptStateWriteNobodyReadsStillAsksForATurn() throws {
        _ = drainedActs()
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()

        let key = PersistentKey("mainThread.kept", of: Double.self)
        let kept = State(wrappedValue: 1.0, persistentKey: key)

        XCTAssertEqual(asked { kept.wrappedValue = 0.5 }, 1, "the write asked for no turn")
        XCTAssertFalse(Renderer.shared.needsRender, "nobody reads it, so no render was asked for")
        XCTAssertGreaterThan(Renderer.shared.actCallsPending, 0, "but the save is pending work")
        XCTAssertEqual(drainedActs().map { $0.name }, ["persistValue"], "which then takes the save")
    }

    /// A MOVEMENT asks for a turn: `move(to:)` books its waiter and writes the
    /// destination onto the value's board - no job, no act, and no render where
    /// nobody reads the value - and the write waiting for a cycle asks as it
    /// lands. A clock whose hands start there would otherwise stand on its first
    /// second until the next event reached the application.
    func testAMovementAsksForATurn() throws {
        let fade = wornOnAQuietBoard()

        // The id the movement will book is the one after this one, answered
        // below the way a host answers an arrival.
        let before = Renderer.shared.book { _ in }
        _ = Renderer.shared.dispatch(before)

        XCTAssertEqual(
            asked { fade.projectedValue.journey.move(to: 0.1, .eased(400, .cubicOut)) }, 1,
            "the movement asked for no turn - the host would not start it until the next event")

        ReplyBuffer.current = .finished([.bool(true)])
        XCTAssertTrue(Renderer.shared.dispatch(before - 1), "the movement booked the next waiter")
    }

    /// A value the host carries, written where nobody reads it, asks for a turn -
    /// the write waits on its board for a cycle, with no render asked for.
    func testACarriedWriteAsksForATurn() throws {
        let fade = wornOnAQuietBoard()

        XCTAssertEqual(asked { fade.wrappedValue = 0.5 }, 1, "the write asked for no turn")
        XCTAssertFalse(Renderer.shared.needsRender, "nobody reads it, so no render was asked for")
        XCTAssertGreaterThan(Renderer.shared.cycleAwake(), 0, "and what waits on its board is work")
    }

    /// A POST FROM THE POOL reaches the host: its job is `MainActor`'s - where the
    /// UI executor holds it, its queueing posts a turn - and the write it
    /// makes asks for a turn as any write does: a value worked out by a detached
    /// task reaches the screen with no event after it.
    func testAPostFromThePoolAsksForATurn() async throws {
        _ = drainedActs()
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()

        let fade = State(1.0)
        let binding = fade.projectedValue
        let renders = Renders()
        renders.render(Shows(fade: fade).node)

        let posts = postingTurns()
        defer { stopPostingTurns() }

        await Task.detached { binding.post(0.25) }.value
        await settle()

        XCTAssertGreaterThan(posts.count.load(ordering: .relaxed), 0, "the post asked for no turn")
        XCTAssertEqual(fade.get(), 0.25, "and its job wrote the value")
        XCTAssertTrue(Renderer.shared.needsRender, "which asks for a render")
    }

    /// How many turns `change` asked the host for, through a poster standing for
    /// the host's, none asked first.
    private func asked(by change: () -> Void) -> Int {
        let posts = postingTurns()
        defer { stopPostingTurns() }

        change()

        return posts.count.load(ordering: .relaxed)
    }

    /// A poster standing for the host's, counting the turns asked from here on -
    /// the one its registration posts at once already drained and uncounted.
    private func postingTurns() -> Posts {
        let posts = Posts()
        UIThreadExecutor.shared.postTurns(with: { posts.post() })
        _ = posts.asked.wait(timeout: .now())
        stateUIRunJobs()
        posts.count.store(0, ordering: .relaxed)
        return posts
    }

    /// No poster any more, and no turn left asked.
    private func stopPostingTurns() {
        UIThreadExecutor.shared.postTurns(with: nil)
        stateUIRunJobs()
    }

    /// A state a rendered view wears as a driven property, on a board with
    /// nothing waiting and nothing queued anywhere else.
    private func wornOnAQuietBoard() -> State<Double> {
        _ = drainedActs()
        stateUIRunJobs()
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()

        let fade = State(wrappedValue: 1.0)
        Renders().render(Text("worn").opacity(fade.projectedValue).id("worn").node)

        _ = HostBoundary.cycle(.display, now: 0, reducesMotion: false)
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

        let patch = renders.render(Button("Tap").onClicked { taps += 1 }.node)
        let id = try XCTUnwrap(patch.events?["clicked"])

        XCTAssertTrue(renders.fire(id))

        XCTAssertEqual(taps, 1, """
            A handler with no suspension in it has to run to completion before \
            dispatch returns. The host renders and drains the act queue \
            straight afterwards, so anything left unfinished would be shown one \
            event late.
            """)
    }

    /// A DISPATCH RUNS ITS HANDLER AND NOTHING ELSE: a job waiting on the UI
    /// thread's queue runs when the host drains it, at its turn - on every
    /// platform at the same point, whichever executor `MainActor` is.
    func testADispatchRunsNoJobWaitingOnTheUIThread() throws {
        let renders = Renders()
        let queued = OnTheUIThreadsQueue()
        var taps = 0

        let patch = renders.render(Button("Tap").onClicked { taps += 1 }.node)
        let id = try XCTUnwrap(patch.events?["clicked"])

        Task.detached { await queued.touch() }

        let deadline = Date().addingTimeInterval(2)
        while UIThreadExecutor.shared.pendingCount == 0, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.002)
        }

        XCTAssertTrue(renders.fire(id))
        XCTAssertEqual(taps, 1, "the handler ran inside the dispatch")
        XCTAssertEqual(queued.touches, 0, "and nothing that waited for the host's drain")

        while stateUIRunJobs() > 0 {}
        XCTAssertEqual(queued.touches, 1, "the host's drain ran it")
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
                .onClicked(gate: .none) {
                    try await Dialogs.alert("//list", message: "saved")
                    reached = true
                }
                .node)

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
                .node)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        let acts = drainedActs()
        XCTAssertEqual(acts.first?.name, "handlerFailed")
        XCTAssertEqual(acts.first?.arguments.first, .string("no route"))
    }

    // MARK: - The rule that keeps it true

    /// THE CORE MAKES NO PROMISE THE COMPILER CANNOT CHECK. Its state is the UI
    /// thread's actor's, and what other threads share stands inside a `Mutex`:
    /// no `@unchecked Sendable`, no `nonisolated(unsafe)`, no `assumeIsolated` -
    /// each a promise that breaks quietly and far from where it was written -
    /// and no `nonisolated(nonsending)`, which on a `MainActor` type takes a
    /// member off the actor, and elsewhere says what the manifests' flag says.
    func testTheCoreMakesNoPromiseTheCompilerCannotCheck() throws {
        let promises = ["@unchecked", "nonisolated(unsafe)", "assumeIsolated", "nonisolated(nonsending)"]
        var made: [String] = []
        var read = 0

        for source in try SourceTree.allSources() where !source.path.hasPrefix("StateUIHost/") {
            read += 1
            let code = UIThreadTests.withoutComments(source.text)

            for promise in promises where code.contains(promise) {
                made.append("\(source.path): \(promise)")
            }
        }

        XCTAssertGreaterThan(read, 300, "the scan read almost nothing")
        XCTAssertEqual(made, [], "the core promises what the compiler cannot check")
    }

    /// THE FOUR NON-NEGOTIABLES, checked instead of remembered - CONTRIBUTING.md
    /// states them, under "Keep the core platform-neutral". Every
    /// one of them breaks a platform silently and far from the cause, which is
    /// why they are rules rather than preferences, and why a test pins them.
    ///
    /// - **The LIBRARY never imports Foundation.** A date in it is three
    ///   integers, and nothing it does needs a formatter or ICU. An
    ///   application may import it; nothing under `Sources/` may.
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
             "the library never imports Foundation - a date in it is three integers"),
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

        for source in try SourceTree.allSources() {
            let code = UIThreadTests.withoutComments(source.text)

            for rule in banned where code.contains(rule.needle) {
                // The one post of MainActor's drain to that queue, for wherever
                // something turns it.
                if rule.needle == "DispatchQueue.main", source.path.hasSuffix("/UIThread.swift") {
                    continue
                }

                // The turn Apple's hosts take after each pass of Apple's own loop, compiled on Apple alone.
                if rule.needle == "RunLoop", source.path.hasSuffix("/RunLoopTurns.swift") {
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

    /// The hosts that run where nothing turns libdispatch's main queue or a run loop - Android, Windows and Linux -
    /// lean on neither: their work for the UI thread goes to MainActor, which each host drains.
    func testNoHostOnAndroidWindowsOrLinuxLeansOnAQueueNothingDrains() throws {
        let banned = [
            "DispatchQueue.main": "nothing drains libdispatch's main queue there - work for the UI thread goes to MainActor",
            "Timer": "a Foundation Timer hangs off a run loop nothing turns there",
            "RunLoop": "a RunLoop is drained by nothing there",
        ]
        var broken: [String] = []
        var read = 0

        for host in ["StateUI.Android", "StateUI.WinUI", "StateUI.GTK"] {
            let root = SourceTree.repository.appendingPathComponent("lib/StateUI/\(host)/Sources")
            for path in try SourceTree.files(under: root, entering: SourceTree.entersSources)
            where path.hasSuffix(".swift") {
                read += 1
                let code = UIThreadTests.withoutComments(try String(
                    contentsOf: root.appendingPathComponent(path), encoding: .utf8))
                for (needle, why) in banned.sorted(by: { $0.key < $1.key }) where code.contains(needle) {
                    broken.append("\(host)/\(path) uses \(needle) - \(why)")
                }
            }
        }

        XCTAssertGreaterThan(read, 100, "the walk read the three hosts' sources")
        XCTAssertEqual(broken, [], broken.joined(separator: "\n"))
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

    /// And the same rule for the code this library cannot annotate.
    ///
    /// `nonisolated(nonsending)` is a spelling, so it only ever covers the
    /// functions here that say it. An application's own `async func` is beyond
    /// reach - and measured, it is exactly where the rule breaks: a helper an
    /// author writes and awaits from a handler runs on the cooperative pool and
    /// comes back off the thread the host draws on, with no diagnostic anywhere.
    ///
    /// The upcoming feature makes caller-inheriting the DEFAULT, which closes
    /// that. It is per-module, so it has to be set in every manifest.
    /// That spread is the reason this is a test: missing one of them costs
    /// nothing at build time and everything at run time.
    ///
    /// Every application's manifest is FOUND rather than listed, so a scaffolded
    /// app is covered the moment it exists.
    func testEverywhereSwiftIsCompiledInheritsTheCallersExecutor() throws {
        var places = [
            "Package.swift",
            "lib/StateUI/StateUI.AppKit/Package.swift",
        ]

        for app in try appManifests() {
            places.append(app)
        }

        var missing: [String] = []

        for place in places {
            let file = SourceTree.repository.appendingPathComponent(place)
            let manifest = Self.withoutComments(try String(contentsOf: file, encoding: .utf8))

            // EVERY TARGET COMPILING SWIFT, each read for its own settings: the
            // one a manifest leaves out is the one whose handlers land off the
            // executor, however often the manifest names the feature elsewhere.
            for target in Self.declaredTargets(in: manifest)
            where Self.holdsSwift(target, besideManifest: file)
                && !Self.compilesWithTheFeature(target, in: manifest) {
                missing.append("\(place) - \(target.name)")
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

    /// A target a manifest declares: its kind, its name, and its call's arguments.
    private struct DeclaredTarget {
        let kind: String
        let name: String
        let arguments: Substring
    }

    private static let feature = "NonisolatedNonsendingByDefault"
    private static var label: Regex<(Substring, Substring)> { try! Regex("(\\w+):") }
    private static var settingsList: Regex<(Substring, Substring)> {
        try! Regex("(?:let|var)\\s+(\\w+)\\s*:\\s*\\[SwiftSetting\\]\\s*=")
    }

    /// The targets `manifest` declares. A `.target(name:)` among a target's
    /// dependencies names one and declares nothing, so a call giving nothing
    /// beyond a name and a condition is none.
    private static func declaredTargets(in manifest: String) -> [DeclaredTarget] {
        var found: [DeclaredTarget] = []
        for kind in ["target", "testTarget", "executableTarget", "macro"] {
            var rest = manifest[...]
            while let opening = rest.range(of: ".\(kind)(") {
                let arguments = balanced(rest[opening.upperBound...])
                let labels = arguments.matches(of: label).map { String($0.1) }
                if let name = quoted("name", in: arguments),
                   labels.contains(where: { $0 != "name" && $0 != "condition" }) {
                    found.append(DeclaredTarget(kind: kind, name: name, arguments: arguments))
                }
                rest = rest[opening.upperBound...]
            }
        }
        return found
    }

    /// The text up to the parenthesis closing the one just opened.
    private static func balanced(_ text: Substring) -> Substring {
        var depth = 1
        var inString = false
        for index in text.indices {
            switch text[index] {
            case "\"": inString.toggle()
            case "(" where !inString: depth += 1
            case ")" where !inString:
                depth -= 1
                if depth == 0 { return text[..<index] }
            default: break
            }
        }
        return text
    }

    /// The string an argument `label` gives, where it gives one.
    private static func quoted(_ label: String, in arguments: Substring) -> String? {
        arguments.firstMatch(of: try! Regex("\\b\(label):\\s*\"([^\"]*)\"", as: (Substring, Substring).self))
            .map { String($0.1) }
    }

    /// Whether `target`'s directory - its `path`, else where the package
    /// manager looks - holds Swift; a relay of C or C++ compiles none.
    private static func holdsSwift(_ target: DeclaredTarget, besideManifest manifest: URL) -> Bool {
        let standing = target.kind == "testTarget" ? "Tests/\(target.name)" : "Sources/\(target.name)"
        let directory = manifest.deletingLastPathComponent()
            .appendingPathComponent(quoted("path", in: target.arguments) ?? standing)
        guard let files = FileManager.default.enumerator(atPath: directory.path) else { return true }
        return files.contains { ($0 as? String)?.hasSuffix(".swift") == true }
    }

    /// Whether `target`'s `swiftSettings` name the feature, or a settings list
    /// `manifest` declares with it.
    private static func compilesWithTheFeature(_ target: DeclaredTarget, in manifest: String) -> Bool {
        guard let settings = target.arguments.range(of: "swiftSettings:") else { return false }
        let given = target.arguments[settings.upperBound...]
        if given.contains(feature) { return true }

        return manifest.matches(of: settingsList).contains { list in
            let initializer = manifest[list.range.upperBound...]
            let declared = initializer.range(of: "\n\n").map { initializer[..<$0.lowerBound] } ?? initializer
            return declared.contains(feature)
                && given.contains(try! Regex("\\b\(list.1)\\b"))
        }
    }

    /// Every active application manifest in the repository, relative to its
    /// root.
    private func appManifests() throws -> [String] {
        var found: [String] = []

        let apps = SourceTree.repository.appendingPathComponent("apps")
        for name in try FileManager.default.contentsOfDirectory(atPath: apps.path).sorted()
        where !name.hasPrefix(".") {
            let manifest = "apps/\(name)/Package.swift"
            if FileManager.default.fileExists(
                atPath: SourceTree.repository.appendingPathComponent(manifest).path) {
                found.append(manifest)
            }
        }
        return found
    }

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
    ///
    /// The countdown's own progress counts the passes, one of its jobs in each:
    /// a job another test left waiting may land in any pass and add none.
    func testADrainIsBoundedSoAJobThatQueuesItselfCannotTakeTheThread() {
        let queued = OnTheUIThreadsQueue()

        // Each job queues the next from INSIDE itself, which is what puts it on
        // the very next pass.
        Task.detached { await queued.countDown(from: 200) }

        let deadline = Date().addingTimeInterval(2)
        while UIThreadExecutor.shared.pendingCount == 0, Date() < deadline {
            Thread.sleep(forTimeInterval: 0.002)
        }

        _ = stateUIRunJobs()
        XCTAssertEqual(200 - queued.left, 64, "a drain ran other than its 64 passes")
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
