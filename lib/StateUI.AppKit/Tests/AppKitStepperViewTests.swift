// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@testable import StateUIAppKit
import XCTest

final class AppKitStepperViewTests: XCTestCase {
    @MainActor
    func testRangeAndIncrementAreAppliedBeforeTheValue() {
        let stepper = AppKitStepperView()

        stepper.apply(
            value: 7,
            writeValue: true,
            minimum: 2,
            maximum: 12,
            increment: 2.5,
            enabled: false)

        XCTAssertEqual(stepper.minValue, 2)
        XCTAssertEqual(stepper.maxValue, 12)
        XCTAssertEqual(stepper.increment, 2.5)
        XCTAssertEqual(stepper.doubleValue, 7)
        XCTAssertFalse(stepper.isEnabled)
        XCTAssertFalse(stepper.valueWraps)
    }

    @MainActor
    func testProgramAndReaderWritesStaySeparate() {
        let stepper = AppKitStepperView()
        var reports: [Double] = []
        stepper.onValueChanged = { reports.append($0) }
        stepper.apply(
            value: 4,
            writeValue: true,
            minimum: 0,
            maximum: 10,
            increment: 1,
            enabled: true)
        XCTAssertTrue(reports.isEmpty)

        stepper.stepForTesting(to: 5)
        XCTAssertEqual(reports, [5])
    }
}

#endif
