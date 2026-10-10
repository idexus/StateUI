// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import StateUIConformance
import XCTest

/// A frame report read as a case compares it.
@MainActor
final class FrameReportTests: XCTestCase {
    /// A corner moved, then rounded, stands where the report standing there reads: a corner at half a point - a
    /// window's top at 107 pixels, two a point - rounds up, and 200 higher it rounds down.
    func testACornerMovedIsRoundedWhereItStands() {
        let before = [0, 0, 120, 60, 0, 53.5, 0, 0]
        let there = [0, 0, 120, 60, 0, -146.5, 0, -200]

        XCTAssertEqual(FrameReport.inWindow(before, movedUp: 200), FrameReport.inWindow(there))
        XCTAssertEqual(FrameReport.inWindow(before, movedUp: 200), [0, -147])
        XCTAssertEqual(FrameReport.inWindow([0, 0], movedUp: 200), [], "no corner reported, none moved")
    }
}
