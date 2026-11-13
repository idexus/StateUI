// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Foundation
import StateUITooling
import Synchronization
import XCTest

final class BuildPermitTests: XCTestCase {
    private func permit() -> BuildPermit {
        BuildPermit(folder: FileManager.default.temporaryDirectory.appendingPathComponent("permit-\(UUID().uuidString)"))
    }

    /// One holds the permit at a time: a second is refused while it is held, and takes it once it is let go.
    func testOneHoldsThePermitAtATime() throws {
        let permit = permit()
        let first = try XCTUnwrap(try permit.take(for: "first"))
        XCTAssertNil(try permit.take(for: "second"))
        XCTAssertEqual(permit.holder, "first")
        first.release()
        let second = try XCTUnwrap(try permit.take(for: "second"))
        XCTAssertEqual(permit.holder, "second")
        second.release()
        XCTAssertNil(permit.holder)
    }

    /// A waiter is told who holds the permit, takes it the moment it is let go, and a cancelled wait takes nothing.
    func testAWaiterIsToldWhoHoldsItAndTakesItWhenFree() async throws {
        let permit = permit()
        let held = try XCTUnwrap(try permit.take(for: "a build of Gallery"))
        let told = Mutex<[String]>([])
        let waiting = Task {
            try await permit.acquire(for: "a build of Notes", poll: .milliseconds(20)) { holder in told.withLock { $0.append(holder) } }
        }
        try await Task.sleep(for: .milliseconds(150))
        held.release()
        let lease = try await waiting.value
        XCTAssertEqual(told.withLock { $0 }, ["a build of Gallery"])
        XCTAssertEqual(permit.holder, "a build of Notes")

        let cancelled = Task { try await permit.acquire(for: "a third", poll: .milliseconds(20)) }
        try await Task.sleep(for: .milliseconds(80))
        cancelled.cancel()
        do {
            _ = try await cancelled.value
            XCTFail("a cancelled wait took the permit")
        } catch is CancellationError {}
        XCTAssertEqual(permit.holder, "a build of Notes")
        lease.release()
    }
}
