// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A run of taps as the platform measures its double tap, where its toolkit counts none.
final class TapRunTests: XCTestCase {
    /// A tap soon after the last and near it carries the run on; one too late or too far starts one.
    func testATapSoonAndNearCarriesTheRunOn() {
        var run = TapRun(interval: .milliseconds(300), slop: 20)
        XCTAssertEqual(run.tapped(at: Point(x: 100, y: 100), time: .milliseconds(-5000)), 1, "from any start")
        XCTAssertEqual(run.tapped(at: Point(x: 110, y: 105), time: .milliseconds(-4800)), 2)
        XCTAssertEqual(run.tapped(at: Point(x: 112, y: 100), time: .milliseconds(-4550)), 3)
        XCTAssertEqual(run.tapped(at: Point(x: 112, y: 100), time: .milliseconds(-4100)), 1, "too late")
        XCTAssertEqual(run.tapped(at: Point(x: 200, y: 100), time: .milliseconds(-4000)), 1, "too far")
    }
}
