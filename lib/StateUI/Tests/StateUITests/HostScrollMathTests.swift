// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

final class HostScrollMathTests: XCTestCase {
    func testHalfwayBelongsToTheNextGridPointInEitherDirection() {
        XCTAssertEqual(HostScrollMath.snapPoint(50, interval: 100, from: 0), 100)
        XCTAssertEqual(HostScrollMath.snapPoint(-50, interval: 100, from: 0), -100)
        XCTAssertEqual(HostScrollMath.nearestItem(150, interval: 100, from: 0), 2)
    }

    func testMomentumScalesTheNativeDestinationFromTheReadersStart() {
        XCTAssertEqual(
            HostScrollMath.projectedDestination(start: 100, nativeDestination: 500, momentum: 0.5),
            300)
        XCTAssertEqual(
            HostScrollMath.projectedDestination(start: 100, nativeDestination: 500, momentum: 0),
            100)
    }

    func testPointLimitIsCountedFromWhereTheMovementStarted() {
        XCTAssertEqual(
            HostScrollMath.heldDestination(
                1_500, movementStart: 0, interval: 300, from: 0, atMost: 1),
            300)
        XCTAssertEqual(
            HostScrollMath.heldDestination(
                -1_500, movementStart: 0, interval: 300, from: 0, atMost: 2),
            -600)
    }

    func testReachableOffsetIsClampedOnlyAfterAnEndIsMeasured() {
        XCTAssertEqual(HostScrollMath.reachable(700, content: 900, viewport: 300), 600)
        XCTAssertEqual(HostScrollMath.reachable(-20, content: 900, viewport: 300), 0)
        XCTAssertEqual(HostScrollMath.reachable(300, content: 0, viewport: 0), 300)
    }

    func testADiscreteInputAlwaysAdvancesToTheNextGridPoint() {
        XCTAssertEqual(
            HostScrollMath.steppedGridDestination(
                from: 100, direction: 1, interval: 100, origin: 0),
            200)
        XCTAssertEqual(
            HostScrollMath.steppedGridDestination(
                from: 149, direction: -1, interval: 100, origin: 0),
            100)
        XCTAssertEqual(
            HostScrollMath.steppedGridDestination(
                from: 120, direction: 1, interval: 100, origin: 50),
            150)
    }
}
