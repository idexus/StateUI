// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import Dispatch
@_spi(Host) import StateUIFoundation
import XCTest

/// Which thread code runs on, on Android's own threads: the foundation's Bionic branch, which no other machine runs.
final class AndroidThreadNumberTests: XCTestCase {
    static var allTests: [(String, (AndroidThreadNumberTests) -> () throws -> Void)] {
        [
            ("testAThreadKeepsItsNumberAndAnotherHasAnother", testAThreadKeepsItsNumberAndAnotherHasAnother),
        ]
    }

    /// A thread keeps its number, and another thread has another.
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
        XCTAssertNotEqual(here, 0)
    }
}
