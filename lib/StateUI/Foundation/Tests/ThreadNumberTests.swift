// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
import StateUIFoundation
import XCTest

/// Which thread code runs on, as a number to compare.
final class ThreadNumberTests: XCTestCase {
    /// A THREAD KEEPS ITS NUMBER, and another thread has another.
    func testAThreadKeepsItsNumberAndAnotherHasAnother() {
        let here = currentThreadNumber()
        nonisolated(unsafe) var there: UInt64 = 0
        let done = DispatchSemaphore(value: 0)
        DispatchQueue(label: "another").async {
            there = currentThreadNumber()
            done.signal()
        }
        done.wait()

        XCTAssertEqual(currentThreadNumber(), here)
        XCTAssertNotEqual(there, here)
    }

    #if canImport(Darwin)
    /// The number is the thread's own, as the debugger shows it - not a hash of it, which changes every run.
    func testTheNumberIsTheThreadsOwn() {
        var id: UInt64 = 0
        pthread_threadid_np(nil, &id)

        XCTAssertEqual(currentThreadNumber(), id)
    }
    #endif
}
