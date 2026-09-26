// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// How a layout measures a child, the same on every host.
final class ChildMeasureTests: XCTestCase {
    /// A stated width is the width a child is measured at, within its bounds; with none, the offer, no wider than
    /// its most width.
    func testAChildIsOfferedItsStatedWidthElseTheOfferWithinItsMost() {
        var values = LayoutValues()
        values.width = 120
        values.maximumWidth = 80
        XCTAssertEqual(values.offer(300), 80)

        values.width = nil
        XCTAssertEqual(values.offer(300), 80)
        XCTAssertEqual(values.offer(50), 50)
        values.maximumWidth = nil
        XCTAssertNil(values.offer(nil))
    }

    /// A child's size is its stated size before what it measured, within its bounds.
    func testAChildsSizeIsItsStatedSizeBeforeItsMeasuredOne() {
        var values = LayoutValues()
        values.height = 40
        values.minimumWidth = 30
        let size = values.sized(LayoutSize(width: 10, height: 99))
        XCTAssertEqual(size.width, 30)
        XCTAssertEqual(size.height, 40)
    }
}
