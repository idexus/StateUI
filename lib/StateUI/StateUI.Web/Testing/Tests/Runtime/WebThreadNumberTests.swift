// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIFoundation
import XCTest

/// Which thread code runs on, on the Web: the foundation's WASI branch, which no other machine runs - one thread
/// runs everything, its number nought.
final class WebThreadNumberTests: XCTestCase {
    func testTheOneThreadIsNumberedNought() {
        XCTAssertEqual(currentThreadNumber(), 0)
        XCTAssertEqual(currentThreadNumber(), currentThreadNumber())
    }
}
