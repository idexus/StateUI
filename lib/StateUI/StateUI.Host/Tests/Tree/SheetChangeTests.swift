// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUIHost
import XCTest

/// What a window's sheets become as its modal stack changes.
@MainActor
final class SheetChangeTests: XCTestCase {
    /// The sheets standing as asked from the bottom stay; the rest leave from the top, and the new come from the
    /// bottom.
    func testTheCommonBottomStaysTheRestLeaveFromTheTop() {
        let change = SheetChange(from: ["A", "B", "C"], to: ["A", "D"]) { $0 == $1 }

        XCTAssertEqual(change.kept, 1)
        XCTAssertEqual(change.leaving, ["C", "B"])
        XCTAssertEqual(change.coming, ["D"])
    }

    /// A sheet swapped beneath one that stays: everything from the change up leaves and comes again, so the one
    /// asked for last stands on top.
    func testASheetSwappedBeneathAnotherTakesTheOneAboveWithIt() {
        let change = SheetChange(from: ["A", "B"], to: ["C", "B"]) { $0 == $1 }

        XCTAssertEqual(change.kept, 0)
        XCTAssertEqual(change.leaving, ["B", "A"])
        XCTAssertEqual(change.coming, ["C", "B"])
    }

    /// Sheets standing as asked change nothing; one more asked for comes over them, one fewer leaves alone.
    func testSheetsStandingAsAskedStay() {
        let same = SheetChange(from: ["A", "B"], to: ["A", "B"]) { $0 == $1 }
        XCTAssertEqual(same.kept, 2)
        XCTAssertEqual(same.leaving, [])
        XCTAssertEqual(same.coming, [])

        let more = SheetChange(from: ["A"], to: ["A", "B"]) { $0 == $1 }
        XCTAssertEqual(more.coming, ["B"])
        XCTAssertEqual(more.leaving, [])

        let fewer = SheetChange(from: ["A", "B"], to: ["A"]) { $0 == $1 }
        XCTAssertEqual(fewer.leaving, ["B"])
        XCTAssertEqual(fewer.coming, [])
    }

    /// A sheet that is the page asked for but no longer stands as it - its native view replaced - leaves and comes
    /// again, with every sheet above it.
    func testASheetNoLongerStandingAsAskedComesAgain() {
        let shown = [("A", 1), ("B", 1)]
        let change = SheetChange(from: shown, to: [("A", 2), ("B", 1)]) { $0 == $1 }

        XCTAssertEqual(change.kept, 0)
        XCTAssertEqual(change.leaving.map(\.0), ["B", "A"])
        XCTAssertEqual(change.coming.map(\.0), ["A", "B"])
    }
}
