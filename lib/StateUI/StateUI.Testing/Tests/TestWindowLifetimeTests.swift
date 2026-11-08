// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) import StateUI
@_spi(Host) @testable import StateUITesting

@MainActor
final class TestWindowLifetimeTests: XCTestCase {
    func testDroppingTheLastWindowEndsItsPageService() async throws {
        let gate = Gate(.runConcurrently)
        var destroyed = 0
        var window: TestWindow? = try await TestWindow(motion: .none) {
            Text("page")
                .onAppearing(gate: gate) { try await Task.sleep(for: .seconds(60)) }
                .onDestroying { destroyed += 1 }
        }
        weak let released = window
        XCTAssertTrue(gate.isBusy)
        window = nil
        XCTAssertNil(released, "the test window itself must be released")
        for _ in 0..<100 { if !gate.isBusy { break }; try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(gate.isBusy, "the last window's page service is still running")
        XCTAssertEqual(destroyed, 1, "the page was never removed from the renderer")
        let cleanup = try await TestWindow(motion: .none) { Text("cleanup") }
        withExtendedLifetime(cleanup) {}
    }

    func testOpeningANewWindowEndsTheOldPageService() async throws {
        let gate = Gate(.runConcurrently)
        var destroyed = 0
        let old = try await TestWindow(motion: .none) {
            Text("page")
                .onAppearing(gate: gate) { try await Task.sleep(for: .seconds(60)) }
                .onDestroying { destroyed += 1 }
        }
        XCTAssertTrue(gate.isBusy)
        let next = try await TestWindow(motion: .none) { Text("next") }
        for _ in 0..<100 { if !gate.isBusy { break }; try await Task.sleep(for: .milliseconds(5)) }
        XCTAssertFalse(gate.isBusy)
        XCTAssertEqual(destroyed, 1)
        withExtendedLifetime((old, next)) {}
    }

    func testClosingWaitsForThePagesFarewellAndCancelsItsService() async throws {
        let gate = Gate(.runConcurrently)
        let farewell = Farewell()
        let window = try await TestWindow(motion: .none) {
            Text("page").accessibilityIdentifier("page")
                .onAppearing(gate: gate) { try await Task.sleep(for: .seconds(60)) }
                .onDestroying { await farewell.wait() }
        }
        let element = try window.element("page")
        var returned = false
        let closing = Task { @MainActor in
            try await window.close()
            returned = true
        }
        for _ in 0..<1000 { if farewell.began { break }; await Task.yield() }
        XCTAssertTrue(farewell.began)
        XCTAssertFalse(returned, "close waits for the lifecycle handler")
        XCTAssertThrowsError(try element.value(TextElementContract.text), "the view is gone while its cleanup waits")
        farewell.release?.resume()
        farewell.release = nil
        try await closing.value

        XCTAssertTrue(returned)
        XCTAssertTrue(farewell.ended)
        XCTAssertFalse(gate.isBusy, "the page's cancelled service finished")
    }

    func testClosingTwiceAndReleasingTheOldWindowLeavesItsSuccessorStanding() async throws {
        var destroyed = 0
        var old: TestWindow? = try await TestWindow(motion: .none) {
            Text("old").onDestroying { destroyed += 1 }
        }
        weak let released = old
        try await old?.close()
        try await old?.close()
        XCTAssertEqual(destroyed, 1)

        let next = try await TestWindow(motion: .none) { CounterPage() }
        old = nil
        XCTAssertNil(released)
        try await next.element("counter.add").perform(.activate)
        XCTAssertEqual(try next.element("counter.add").value(TextElementContract.text), "Clicked 1 time")
        XCTAssertEqual(destroyed, 1)
        try await next.close()
    }

    func testClosingReleasesThePageWhileTheTestWindowIsStillHeld() async throws {
        var page: HeldPage? = HeldPage()
        weak let released = page
        let window = try await TestWindow(motion: .none) { [page = page!] in page }
        page = nil
        XCTAssertNotNil(released, "the standing page is held by the renderer")

        try await window.close()

        XCTAssertNil(released, "neither the renderer nor the closed driver keeps the page")
        withExtendedLifetime(window) {}
    }

    func testClosingWaitsOnNoUnrelatedRun() async throws {
        let gate = Gate(.runConcurrently)
        let unrelated = Task(gate: gate) { try await Task.sleep(for: .seconds(60)) }
        defer { unrelated.cancel() }
        let window = try await TestWindow(motion: .none) { Text("page") }
        XCTAssertTrue(gate.isBusy)

        try await window.close()

        XCTAssertTrue(gate.isBusy, "a task outside the page belongs to its caller")
    }

    func testUnfinishedCleanupFailsExplicitlyAndCanBeAwaitedAgain() async throws {
        let farewell = Farewell()
        let window = try await TestWindow(motion: .none) { Text("page").onDestroying { await farewell.wait() } }

        do {
            try await window.close(until: .now)
            XCTFail("unfinished lifecycle work passed its deadline")
        } catch let failure as TestFailure {
            XCTAssertTrue(failure.description.contains("lifecycle work did not finish"))
        }
        XCTAssertTrue(farewell.began)
        XCTAssertFalse(farewell.ended)
        farewell.release?.resume()
        farewell.release = nil
        try await window.close()
        XCTAssertTrue(farewell.ended)
    }

    func testCancellingTheWaitLeavesTheWindowClosed() async throws {
        let farewell = Farewell()
        let window = try await TestWindow(motion: .none) {
            Text("page").accessibilityIdentifier("page").onDestroying { await farewell.wait() }
        }
        let closing = Task { @MainActor in try await window.close() }
        for _ in 0..<1000 { if farewell.began { break }; await Task.yield() }
        XCTAssertTrue(farewell.began)
        closing.cancel()
        do {
            try await closing.value
            XCTFail("a cancelled wait returned normally")
        } catch is CancellationError {}
        XCTAssertThrowsError(try window.element("page"))

        farewell.release?.resume()
        farewell.release = nil
        try await window.close()
        XCTAssertTrue(farewell.ended)
    }

    func testAWindowOpenedByFarewellIsNotClosedWithItsPredecessor() async throws {
        let driver = CoreDriver()
        let service = Gate(.runConcurrently)
        let work = Farewell()
        defer { work.release?.resume() }
        var successor: TestWindow?
        let old = TestWindow(driver: driver, motion: .none) {
            Text("old").onDestroying {
                successor = TestWindow(driver: driver, motion: .none) {
                    CounterPage().onAppearing(gate: service) { await work.wait() }
                }
            }
        }

        try await old.close(until: .now + .seconds(1))

        let next = try XCTUnwrap(successor)
        XCTAssertTrue(service.isBusy, "the successor's work belongs to its own page")
        try await next.element("counter.add").perform(.activate)
        XCTAssertEqual(try next.element("counter.add").value(TextElementContract.text), "Clicked 1 time")
        work.release?.resume()
        work.release = nil
        try await next.close()
    }

    func testClosingStartsDisappearingBeforeDestroyingAndAwaitsBoth() async throws {
        let disappearing = Farewell()
        let destroying = Farewell()
        var order: [String] = []
        let window = try await TestWindow(motion: .none) {
            Text("page")
                .onDisappearing(policy: .runConcurrently) {
                    order.append("disappearing")
                    await disappearing.wait()
                    order.append("disappeared")
                }
                .onDestroying {
                    order.append("destroying")
                    await destroying.wait()
                    order.append("destroyed")
                }
        }
        var returned = false
        let closing = Task { @MainActor in
            try await window.close()
            returned = true
        }
        for _ in 0..<1000 { if destroying.began { break }; await Task.yield() }
        XCTAssertEqual(order, ["disappearing", "destroying"])

        destroying.release?.resume()
        destroying.release = nil
        for _ in 0..<1000 { if destroying.ended { break }; await Task.yield() }
        XCTAssertFalse(returned, "the disappearing handler still owns cleanup work")
        disappearing.release?.resume()
        disappearing.release = nil
        try await closing.value
        XCTAssertEqual(order, ["disappearing", "destroying", "destroyed", "disappeared"])
    }

    func testClosingAwaitsGatedWorkStartedByItsFarewell() async throws {
        let gate = Gate(.runConcurrently)
        let farewell = Farewell()
        let window = try await TestWindow(motion: .none) {
            Text("page").onDestroying {
                Task(gate: gate) { await farewell.wait() }
            }
        }
        var returned = false
        let closing = Task { @MainActor in
            try await window.close()
            returned = true
        }
        for _ in 0..<1000 { if farewell.began { break }; await Task.yield() }
        XCTAssertTrue(farewell.began)
        for _ in 0..<100 { await Task.yield() }
        XCTAssertFalse(returned, "cleanup's gated work is part of the same teardown")
        farewell.release?.resume()
        farewell.release = nil
        try await closing.value
        XCTAssertTrue(farewell.ended)
        XCTAssertFalse(gate.isBusy)
    }

    func testAnActAskedByFarewellFailsWithoutWaitingForAClosedHost() async throws {
        var reason: String?
        let window = try await TestWindow(motion: .none) {
            Text("page").onDestroying {
                do {
                    _ = try await HostBoundary.application.clipboard.read()
                    XCTFail("the closed host answered an act")
                } catch StateUIError.notPerformed(_, let why) {
                    reason = why
                }
            }
        }

        try await window.close(until: .now + .seconds(1))

        XCTAssertEqual(reason, "the application's host is closing")
    }

    func testCompletedTeardownIsNotReopenedByLaterUnstructuredWork() async throws {
        let later = Farewell()
        let work = Farewell()
        let gate = Gate(.runConcurrently)
        var unstructured: Task<Void, Never>?
        let window = try await TestWindow(motion: .none) {
            Text("page").onDestroying {
                unstructured = Task { @MainActor in
                    await later.wait()
                    Task(gate: gate) { await work.wait() }
                }
            }
        }
        let registration = Renderer.shared.applicationRegistration

        try await window.close()
        let ended = Renderer.shared.clearApplication(expected: registration)
        XCTAssertTrue(ended.isFinished)
        for _ in 0..<1000 { if later.began { break }; await Task.yield() }
        XCTAssertTrue(later.began)
        later.release?.resume()
        later.release = nil
        for _ in 0..<1000 { if work.began { break }; await Task.yield() }
        XCTAssertTrue(work.began)
        XCTAssertTrue(gate.isBusy)
        XCTAssertTrue(ended.isFinished, "future unstructured work cannot reopen completed cleanup")

        work.release?.resume()
        work.release = nil
        await unstructured?.value
        for _ in 0..<1000 { if !gate.isBusy { break }; await Task.yield() }
        XCTAssertFalse(gate.isBusy)
        try await window.close()
    }
}

@MainActor
private final class Farewell {
    var began = false
    var ended = false
    var release: CheckedContinuation<Void, Never>?

    func wait() async {
        began = true
        await withCheckedContinuation { release = $0 }
        ended = true
    }
}

private final class HeldPage: View {
    var body: some View { Text("held") }
}
