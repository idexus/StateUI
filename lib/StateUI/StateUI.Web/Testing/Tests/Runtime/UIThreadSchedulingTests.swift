// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// On WebAssembly no thread sleeps: a task's sleep is kept for later by the UI thread's executor, which says when it
/// comes due, and it comes due on the first drain after its time.
///
/// XCTest's own main runs on Swift's cooperative executor, which stays this process's default - a renderer made here
/// would make the UI thread's executor the main one under it - so the woken task resumes there, between drains.
final class UIThreadSchedulingTests: XCTestCase {
    func testASleepComesDueOnTheFirstDrainAfterItsTime() async {
        nonisolated(unsafe) var woke = false
        let executor = UIThreadExecutor.shared
        let since = ContinuousClock.now
        Task(executorPreference: executor) {
            try? await Task.sleep(for: .milliseconds(20))
            woke = true
        }

        executor.drain()
        await Task.yield()
        XCTAssertFalse(woke, "a sleep of 20 ms woke at once")
        let due = executor.nextDue
        XCTAssertNotNil(due, "the sleep is not kept for later")
        XCTAssertLessThanOrEqual(due ?? .seconds(1), .milliseconds(20))

        while !woke, since.duration(to: .now) < .seconds(2) {
            executor.drain()
            await Task.yield()
        }
        XCTAssertTrue(woke, "the sleep never came due")
        XCTAssertGreaterThanOrEqual(since.duration(to: .now), .milliseconds(20), "it came due before its time")
        XCTAssertNil(executor.nextDue)
    }
}
