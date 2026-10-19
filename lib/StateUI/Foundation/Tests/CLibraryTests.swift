// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIFoundation
import XCTest

/// The platform's C library, reached by one import on every platform.
final class CLibraryTests: XCTestCase {
    /// ITS ARITHMETIC IS AT HAND with `StateUIFoundation` alone, the same functions whichever platform builds it.
    func testItsArithmeticIsAtHand() {
        XCTAssertEqual(exp(0.0), 1)
        XCTAssertEqual(sin(Double.pi / 2), 1, accuracy: 1e-12)
        XCTAssertEqual(pow(2.0, 10.0), 1_024)
        XCTAssertEqual(atan2(1.0, 1.0), Double.pi / 4, accuracy: 1e-12)
    }
}
