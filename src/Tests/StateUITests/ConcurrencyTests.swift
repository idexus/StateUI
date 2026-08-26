// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Commands sent from more than one thread at once.
//
// `async let` runs its child on the cooperative pool - Swift's design, a child
// task does not inherit the parent's actor - so two animations started with
// `async let` reach `Renderer.send` from pool threads while the host thread is
// taking commands and dispatching completions. The registry behind that is a
// dictionary and an array, and unguarded they were a data race: a lost
// continuation on a good day, which reads as a handler frozen at its `await`,
// and corrupted memory on a bad one, which took real devices down. Measured on
// Mac Catalyst, an iOS device and an Android device alike, in the gallery's
// concurrent-animation sample.
//
// What these tests pin is the guarantee, not the crash: every act queued from a
// child task is taken exactly once, answered exactly once, and every awaiting
// handler comes back. Against the unguarded registry this fails by count -
// nondeterministically, but a loss is a red test rather than a hang, because
// the host loop below has an end.

import StateUIWireProbe
import XCTest
@testable import StateUI

/// The gallery Card's exact shape: the handler literal written inside a
/// conforming struct's `body` GETTER, an `async let` child inside it, and
/// GETTER LOCALS carrying the stored properties into the closure.
///
/// The locals are the point. Written with an explicit CAPTURE LIST instead -
/// `{ [name, action] in ... }` - the compiler (Swift 6.3) moves the whole
/// closure off this library's executor: it does not run inline from the
/// dispatch (no command is queued), no job and no pending resume ever show,
/// and on a device the press froze until the next event reached the app.
/// Proven both ways against the test below; the sister trap to the one
/// Support.swift documents for test-method closures capturing a class.
private struct PressCard: Element {
    let press = ControlState<Button>()
    let action: EventHandler

    var body: Node {
        let press = self.press
        let action = self.action

        return Button("Go")
            .assign(press)
            .onClicked {
                _ = try await press.focus()
                async let restored: Bool = press.focus()
                try await action()
                _ = try await restored
            }
            .body
    }
}

final class ConcurrencyTests: XCTestCase {
    /// Answers every act still queued and runs every job until nothing is
    /// left, so a test that stopped mid-handler leaves no suspended handler
    /// and no unanswered command for the NEXT test to trip over - a stray
    /// completion id was the first thing another test's `first` found.
    private func drainEverything() async {
        var quiet = 0
        let deadline = Date().addingTimeInterval(5)

        while quiet < 2 && Date() < deadline {
            let ids = completionIds(in: Renderer.shared.takeCommandsWire())

            for completion in ids {
                ReplyBuffer.current = .finished([.bool(true)])
                _ = Renderer.shared.dispatch(completion)
            }

            let ran = stateUIRunJobs()

            if ids.isEmpty && ran == 0 && MainThreadExecutor.shared.pendingCount == 0
                && Renderer.shared.resumesPending == 0 {
                quiet += 1
            } else {
                quiet = 0
            }

            try? await Task.sleep(nanoseconds: 100_000)
        }
    }

    /// Every completion id in a commands message, in order.
    private func completionIds(in bytes: [UInt8]) -> [Int] {
        WireProbe.completions(bytes)
    }

    /// The host's whole loop, against a handler whose animations run as child
    /// tasks: take what was queued, answer each act, run the jobs the resumes
    /// produce, until the handler says it has finished or the patience runs out.
    func testActsQueuedFromChildTasksAreEachAnsweredAndAllComeBack() async throws {
        let renders = Renders()
        var finished = 0

        _ = Renderer.shared.takeCommandsWire()

        let laps = 40
        let patch = renders.render(
            Button("Play")
                .onClicked {
                    for _ in 0..<laps {
                        // Two acts in flight at once, from two pool threads -
                        // the shape the gallery's concurrent sample has, and
                        // the one that corrupted the unguarded registry.
                        async let one: Bool = named("a", BoxView.self).focus()
                        async let two: Bool = named("b", BoxView.self).focus()
                        _ = try await (one, two)

                        finished += 1
                    }
                }
                .body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        var answered = 0
        let deadline = Date().addingTimeInterval(20)

        while finished < laps && Date() < deadline {
            for completion in completionIds(in: Renderer.shared.takeCommandsWire()) {
                ReplyBuffer.current = .finished([.bool(true)])
                XCTAssertTrue(
                    Renderer.shared.dispatch(completion),
                    "a completion the host holds must find its continuation - "
                        + "losing one is exactly what the unguarded registry did")
                answered += 1
            }

            stateUIRunJobs()

            // Give the pool threads room to send; nothing here is timing-based
            // beyond that, the loop ending on the count.
            try? await Task.sleep(nanoseconds: 100_000)
        }

        XCTAssertEqual(finished, laps, "every lap's children came back")
        XCTAssertEqual(answered, laps * 2, "every act was queued once and answered once")
    }

    /// A handler with a child STARTED below its first await, held to the
    /// counters the HOST polls: after the first act's completion is
    /// dispatched, the resumed handler must be visible - as a pending resume
    /// or a landed job - or the drain gives up and the handler sits until
    /// the next event. The method-written closure; `PressCard` above is the
    /// same contract for the getter-written one.
    func testAHandlerWithAChildBelowStaysOnTheLibrarysExecutor() async throws {
        let renders = Renders()
        var reached = false

        _ = Renderer.shared.takeCommandsWire()

        let patch = renders.render(
            Button("Go")
                .onClicked {
                    _ = try await named("a", BoxView.self).focus()
                    async let restored: Bool = named("a", BoxView.self).focus()
                    _ = try await named("b", BoxView.self).focus()
                    _ = try await restored
                    reached = true
                }
                .body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        let first = try XCTUnwrap(completionIds(in: Renderer.shared.takeCommandsWire()).first)
        ReplyBuffer.current = .finished([.bool(true)])
        XCTAssertTrue(Renderer.shared.dispatch(first))

        // The host's two questions, asked the way ScheduleDrain asks them.
        // The job may take a moment to land; what may NOT happen is quiet.
        var visible = false
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            if MainThreadExecutor.shared.pendingCount > 0 || Renderer.shared.resumesPending > 0 {
                visible = true
                break
            }
            try? await Task.sleep(nanoseconds: 10_000)
        }

        XCTAssertTrue(
            visible,
            "the resumed handler went to another scheduler - the host's drain "
                + "sees nothing and the interface freezes until the next event")

        await drainEverything()
        XCTAssertTrue(reached, "the drained handler ran to its end")
    }

    /// The same contract, written where the gallery writes it: in a
    /// conforming struct's `body` getter. Fails - no command queued at all -
    /// when `PressCard`'s closure takes its values through a capture list
    /// instead of the getter locals; see the doc on `PressCard`.
    func testACardShapedHandlerStaysOnTheLibrarysExecutor() async throws {
        let renders = Renders()

        _ = Renderer.shared.takeCommandsWire()

        let patch = renders.render(
            PressCard(
                action: { _ = try await named("b", BoxView.self).focus() }
            ).body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        let first = try XCTUnwrap(completionIds(in: Renderer.shared.takeCommandsWire()).first)
        ReplyBuffer.current = .finished([.bool(true)])
        XCTAssertTrue(Renderer.shared.dispatch(first))

        var visible = false
        let deadline = Date().addingTimeInterval(2)

        while Date() < deadline {
            if MainThreadExecutor.shared.pendingCount > 0 || Renderer.shared.resumesPending > 0 {
                visible = true
                break
            }
            try? await Task.sleep(nanoseconds: 10_000)
        }

        XCTAssertTrue(
            visible,
            "the resumed handler went to another scheduler - the host's drain "
                + "sees nothing and the interface freezes until the next event")

        await drainEverything()
    }

    /// The gallery Card's shape: an act awaited, a child STARTED and left
    /// running, another act awaited beside it, the child awaited last. What
    /// the press animation does - dip, then the return and the navigation
    /// starting together - and the shape that froze the gallery on Mac
    /// Catalyst with the handler never resuming from its FIRST await.
    func testAChildStartedBetweenTwoActsLeavesBothAnswered() async throws {
        let renders = Renders()
        var reached = false

        _ = Renderer.shared.takeCommandsWire()

        let patch = renders.render(
            Button("Go")
                .onClicked {
                    _ = try await named("a", BoxView.self).focus()
                    async let restored: Bool = named("a", BoxView.self).focus()
                    _ = try await named("b", BoxView.self).focus()
                    _ = try await restored
                    reached = true
                }
                .body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        let deadline = Date().addingTimeInterval(20)

        while !reached && Date() < deadline {
            for completion in completionIds(in: Renderer.shared.takeCommandsWire()) {
                ReplyBuffer.current = .finished([.bool(true)])
                XCTAssertTrue(
                    Renderer.shared.dispatch(completion),
                    "a completion the host holds must find its continuation")
            }

            stateUIRunJobs()
            try? await Task.sleep(nanoseconds: 100_000)
        }

        XCTAssertTrue(reached, "the handler never came back")
    }

    /// The counters the host polls, asked from the host's side of the race: a
    /// resume can be owed with the queue still empty, and a job can be waiting
    /// with no resume owed - a parent whose children have already lowered the
    /// count. The drain loop asks BOTH, so both have to be visible.
    func testAJobIsVisibleToTheHostBeforeItIsRun() async throws {
        let renders = Renders()
        var reached = false

        _ = Renderer.shared.takeCommandsWire()

        let patch = renders.render(
            Button("Go")
                .onClicked {
                    _ = try await named("a", BoxView.self).focus()
                    reached = true
                }
                .body)

        let id = try XCTUnwrap(patch.events?["clicked"])
        XCTAssertTrue(renders.fire(id))

        let completion = try XCTUnwrap(completionIds(in: Renderer.shared.takeCommandsWire()).first)

        ReplyBuffer.current = .finished([.bool(true)])
        XCTAssertTrue(Renderer.shared.dispatch(completion))

        // Between the report and the drain, the host's two questions: the job
        // may not exist yet, but SOMETHING must say work is coming or already
        // there - this is what the drain loop keeps looking on.
        let deadline = Date().addingTimeInterval(2)
        while Date() < deadline {
            if MainThreadExecutor.shared.pendingCount > 0 || Renderer.shared.resumesPending > 0 {
                break
            }
            try? await Task.sleep(nanoseconds: 10_000)
        }

        XCTAssertTrue(
            MainThreadExecutor.shared.pendingCount > 0 || Renderer.shared.resumesPending > 0,
            "a resumed handler that has not run yet must be visible to the host "
                + "through one of the two counters it polls")

        await settle()
        XCTAssertTrue(reached)
    }
}
