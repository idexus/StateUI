// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// What `arrived()` answers each waiter: the movement's end, a failure, or - for a task cancelled while it waits - its
/// own cancellation, the movement going on for the others; every resume counted once, whatever it carries.
@MainActor
final class ArrivalTests: XCTestCase {
    /// A waiter whose task is cancelled stops waiting at once with `CancellationError`; another waiting for the same
    /// movement waits on, and hears its end.
    func testACancelledWaiterStopsAloneAndTheMovementGoesOn() async throws {
        let arrival = Arrival()
        let before = Renderer.shared.resumesPending
        var cancelledEnded: Result<Bool, any Error>?
        var otherEnded: Result<Bool, any Error>?

        let cancelled = Task { @MainActor in
            do { cancelledEnded = .success(try await arrival.arrived()) } catch { cancelledEnded = .failure(error) }
        }
        let other = Task { @MainActor in
            do { otherEnded = .success(try await arrival.arrived()) } catch { otherEnded = .failure(error) }
        }
        await settle { false }

        cancelled.cancel()
        await settle { cancelledEnded != nil }

        XCTAssertTrue((cancelledEnded.map { if case .failure(let e) = $0 { e is CancellationError } else { false } }) ?? false,
                      "the cancelled waiter stopped with its cancellation: \(String(describing: cancelledEnded))")
        XCTAssertNil(otherEnded, "the other waits on")
        XCTAssertNil(arrival.ended, "the movement goes on")

        arrival.land(.finished([.bool(true)]))
        await settle { otherEnded != nil }
        XCTAssertEqual(try otherEnded?.get(), true)
        _ = await (cancelled.value, other.value)
        XCTAssertEqual(Renderer.shared.resumesPending, before, "every resume was counted once and taken back")
    }

    /// A task cancelled before it waits never waits.
    func testATaskCancelledBeforeItWaitsStopsAtOnce() async {
        let arrival = Arrival()
        var ended: Result<Bool, any Error>?

        let task = Task { @MainActor in
            withUnsafeCurrentTask { $0?.cancel() }
            do { ended = .success(try await arrival.arrived()) } catch { ended = .failure(error) }
        }
        await settle { ended != nil }

        XCTAssertNotNil(ended, "a cancelled task waited")
        arrival.land(.finished([.bool(true)]))
        _ = await task.value
    }

    /// A failure answered is a resume like any other: counted as it lands, taken back as the waiter runs again.
    func testAFailureTakesItsResumeBack() async {
        let arrival = Arrival()
        let before = Renderer.shared.resumesPending
        var ended: Result<Bool, any Error>?

        let task = Task { @MainActor in
            do { ended = .success(try await arrival.arrived()) } catch { ended = .failure(error) }
        }
        await settle { false }

        arrival.land(.failed("the host cannot carry it"))
        _ = await task.value

        XCTAssertNotNil(ended)
        XCTAssertEqual(Renderer.shared.resumesPending, before, "a failure left its resume counted")
    }

    /// Lets the waiting tasks run, a bounded number of turns, until `done`.
    private func settle(until done: () -> Bool) async {
        for _ in 0..<200 {
            if done() { return }
            await Task.yield()
        }
    }
}
