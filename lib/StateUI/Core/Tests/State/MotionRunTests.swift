// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// What `result()` answers each waiter: the movement's one result, or - for a task cancelled while it waits - its
/// own cancellation, the movement going on for the others; every resume counted once, whatever it carries.
@MainActor
final class MotionRunTests: XCTestCase {
    override func setUp() async throws {
        Renderer.shared.clearInvalidation()
        Renderer.shared.clearStates()
    }

    /// EVERY WAITER HEARS THE ONE RESULT, and one asking after the end hears it at once.
    func testEveryWaiterHearsTheOneResult() async throws {
        let run = MotionRun()
        var heard: [MotionResult] = []

        let waiters = (0..<3).map { _ in
            Task { @MainActor in heard.append(try await run.result()) }
        }
        await settle { false }
        XCTAssertTrue(heard.isEmpty, "under way, nobody is answered")

        run.end(.reached(.animated))
        for waiter in waiters { try await waiter.value }

        XCTAssertEqual(heard, Array(repeating: .reached(.animated), count: 3))
        let after = try await run.result()
        XCTAssertEqual(after, .reached(.animated), "asked after the end, it answers at once")
    }

    /// ONE RESULT, THE FIRST: a second word changes nothing.
    func testAMovementEndsOnce() {
        let run = MotionRun()

        run.end(.superseded)
        run.end(.reached(.animated))
        run.land(.finished([.number(MotionRun.code(of: .stopped))]))

        XCTAssertEqual(run.outcome, .superseded)
    }

    /// A waiter whose task is cancelled stops waiting at once with `CancellationError`; another waiting for the same
    /// movement waits on, and hears its end. The movement itself is not ended by it.
    func testACancelledWaiterStopsAloneAndTheMovementGoesOn() async throws {
        let run = MotionRun()
        let before = Renderer.shared.resumesPending
        var cancelledEnded: Result<MotionResult, any Error>?
        var otherEnded: Result<MotionResult, any Error>?

        let cancelled = Task { @MainActor in
            do { cancelledEnded = .success(try await run.result()) } catch { cancelledEnded = .failure(error) }
        }
        let other = Task { @MainActor in
            do { otherEnded = .success(try await run.result()) } catch { otherEnded = .failure(error) }
        }
        await settle { false }

        cancelled.cancel()
        await settle { cancelledEnded != nil }

        XCTAssertTrue((cancelledEnded.map { if case .failure(let e) = $0 { e is CancellationError } else { false } }) ?? false,
                      "the cancelled waiter stopped with its cancellation: \(String(describing: cancelledEnded))")
        XCTAssertNil(otherEnded, "the other waits on")
        XCTAssertNil(run.outcome, "the movement goes on")

        run.end(.reached(.animated))
        await settle { otherEnded != nil }
        XCTAssertEqual(try otherEnded?.get(), .reached(.animated))
        _ = await (cancelled.value, other.value)
        XCTAssertEqual(Renderer.shared.resumesPending, before, "every resume was counted once and taken back")
    }

    /// A task cancelled before it waits never waits.
    func testATaskCancelledBeforeItWaitsStopsAtOnce() async {
        let run = MotionRun()
        var ended: Result<MotionResult, any Error>?

        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            do { ended = .success(try await run.result()) } catch { ended = .failure(error) }
        }
        await settle { ended != nil }

        XCTAssertNotNil(ended, "a cancelled task waited")
        run.end(.reached(.animated))
        _ = await task.value
    }

    /// THE HOST GONE IS NO RECEIVER LEFT: a waiter the application's end, or a failing host, takes hears
    /// `.detached` - a result, never an error - and its resume is taken back.
    func testAHostThatWentDetachesTheMovement() async throws {
        let before = Renderer.shared.resumesPending
        for reply in [Reply.failed("the host cannot carry it"), .cancelled] {
            let run = MotionRun()
            var ended: MotionResult?

            let task = Task { @MainActor in ended = try await run.result() }
            await settle { false }
            run.land(reply)
            try await task.value

            XCTAssertEqual(ended, .detached)
        }
        XCTAssertEqual(Renderer.shared.resumesPending, before)
    }

    /// NO MOVEMENT IS LEFT OPEN: a run that ended is counted out, whoever ended it.
    func testAnEndedMovementIsCountedOut() {
        let open = MotionRun.open
        let runs = [MotionRun(), MotionRun(), MotionRun(ended: .notStarted(.noReceiver))]
        XCTAssertEqual(MotionRun.open, open + 2, "a movement refused was never under way")

        runs[0].end(.stopped)
        runs[1].land(.finished([.number(MotionRun.code(of: .detached))]))
        XCTAssertEqual(MotionRun.open, open)
    }

    /// A MOVE WAITED ON THROUGH THE HOST: shown, a move waits; the host's word of how its run ended is the result.
    func testAMoveHearsTheHostsOutcome() async throws {
        let fade = State(wrappedValue: 1.0)
        let renders = Renders()
        renders.render(Rectangle().opacity(fade.projectedValue).node)

        // The waiter this move books, told from whatever earlier movements left waiting.
        let waitingBefore = Set(Renderer.shared.waiting)
        let run = fade.projectedValue.journey.move(to: 0, .eased(.milliseconds(300)))
        XCTAssertNil(run.outcome)
        let waiter = Task { @MainActor in try await run.result() }
        await settle { false }

        let id = try XCTUnwrap(Set(Renderer.shared.waiting).subtracting(waitingBefore).first)
        XCTAssertTrue(HostBoundary.complete(id, as: .immediate(.reducedMotion)))

        let result = try await waiter.value
        XCTAssertEqual(result, .reached(.immediate(.reducedMotion)))
        _ = renders
    }

    /// Lets the waiting tasks run, a bounded number of turns, until `done`.
    private func settle(until done: () -> Bool) async {
        for _ in 0..<200 {
            if done() { return }
            await Task.yield()
        }
    }
}
