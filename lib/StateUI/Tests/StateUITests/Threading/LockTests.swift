// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
import XCTest
@testable import StateUI

/// State more than one thread touches stands behind a `Lock` - Lock.swift.
final class LockTests: XCTestCase {
    /// Eight threads, ten thousand holds each, one count: nothing is lost.
    func testEveryHoldCountsWhileManyThreadsHoldTheLock() {
        final class Counter: @unchecked Sendable {
            let guarded = Lock()
            var count = 0
        }

        let counter = Counter()
        DispatchQueue.concurrentPerform(iterations: 8) { _ in
            for _ in 0..<10_000 {
                counter.guarded.withLock { counter.count += 1 }
            }
        }

        XCTAssertEqual(counter.guarded.withLock { counter.count }, 80_000)
    }

    /// One way to lock in the library: `Lock`. A serial queue held as a mutex
    /// and a `Mutex` of a class's own are both refused, so the next lock
    /// written is the one every other place uses.
    func testTheLibraryLocksWithLockAlone() throws {
        var offenders: [String] = []

        for (path, text) in try Fixtures.allSources() {
            if text.contains("DispatchQueue(") { offenders.append("\(path): DispatchQueue(") }
            if text.contains(".sync {") || text.contains(".sync(") { offenders.append("\(path): .sync") }
            if text.contains("Mutex(") && !path.hasSuffix("/Lock.swift") { offenders.append("\(path): Mutex(") }
        }

        XCTAssertEqual(offenders, [], "the library locks with `Lock`")
    }
}
