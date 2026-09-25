// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// Where a placing run stands a ZStack's children, and in what order it draws them.
final class PlacingRunTests: XCTestCase {
    private func placed(z: Int, width: Double = 10, opacity: Double = 1, shade: Double = 0) -> HostPlacement {
        HostPlacement(
            bounds: Rect(x: 1, y: 2, width: width, height: -4), translationX: 0, translationY: 0, rotation: 0,
            scaleX: 1, scaleY: 1, opacity: opacity, zIndex: z, shade: shade)
    }

    /// Children are drawn back to front by their z-index, the earlier first among equals, those the run places
    /// none of after them.
    func testChildrenAreDrawnByTheirZIndexThenInTheirOrder() {
        let order = ZStackArithmetic.drawingOrder(of: 5, placedBy: [placed(z: 2), placed(z: 0), placed(z: 2)])
        XCTAssertEqual(order, [1, 0, 2, 3, 4])
        XCTAssertEqual(ZStackArithmetic.drawingOrder(of: 2, placedBy: []), [0, 1])
    }

    /// A placed child has no size below nothing, and its opacity stands between 0 and 1.
    func testAPlaceHasNoSizeBelowNothing() {
        XCTAssertEqual(placed(z: 0, width: -3).place, Rect(x: 1, y: 2, width: 0, height: 0))
        XCTAssertEqual([placed(z: 0, opacity: 1.5), placed(z: 0, opacity: -1)].map(\.drawnOpacity), [1, 0])
    }

    /// A card's shade is drawn between nothing and whole.
    func testAShadeIsDrawnWithinWhole() {
        XCTAssertEqual(placed(z: 0, shade: -0.2).drawnShade, 0)
        XCTAssertEqual(placed(z: 0, shade: 1.5).drawnShade, 1)
        XCTAssertEqual(placed(z: 0, shade: 0.4).drawnShade, 0.4)
    }
}
