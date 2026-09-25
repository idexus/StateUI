// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

final class StepArithmeticTests: XCTestCase {
    /// A stepped number is written with as many decimals as its step and its range take, and no more than six.
    func testANumberTakesTheDecimalsItsStepTakes() {
        XCTAssertEqual(StepArithmetic.decimals(of: [1, 0, 10, 3]), 0)
        XCTAssertEqual(StepArithmetic.decimals(of: [0.25, 0, 1, 0.5]), 2)
        XCTAssertEqual(StepArithmetic.decimals(of: [0.1, 0, 1, .nan]), 1)
        XCTAssertEqual(StepArithmetic.decimals(of: [1.0 / 3]), 6)
    }
}
