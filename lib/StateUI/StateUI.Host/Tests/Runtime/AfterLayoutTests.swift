// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUIHost
import XCTest

/// Work that waits for a layout pass to end.
@MainActor
final class AfterLayoutTests: XCTestCase {
    /// Work waits for the pass's end, runs in the order it came, and the host is asked once for all of it.
    func testWorkRunsAtThePassesEndInOrderAskedOnce() {
        let queue = AfterLayout()
        var asked = 0
        var ran: [Int] = []
        queue.askForPassEnd = { asked += 1 }

        queue.run { ran.append(1) }
        queue.run { ran.append(2) }
        XCTAssertEqual(ran, [], "nothing runs before the pass is over")
        XCTAssertEqual(asked, 1)

        XCTAssertTrue(queue.passEnded())
        XCTAssertEqual(ran, [1, 2])
        XCTAssertFalse(queue.passEnded(), "nothing waits any more")
    }

    /// Work that comes while the queue runs waits for the next pass, and asks for it.
    func testWorkComingWhileItRunsWaitsForTheNextPass() {
        let queue = AfterLayout()
        var asked = 0
        var ran: [String] = []
        queue.askForPassEnd = { asked += 1 }

        queue.run {
            ran.append("first")
            queue.run { ran.append("later") }
        }
        queue.passEnded()

        XCTAssertEqual(ran, ["first"])
        XCTAssertEqual(asked, 2, "the later work asked for its own pass")
        queue.passEnded()
        XCTAssertEqual(ran, ["first", "later"])
    }
}
