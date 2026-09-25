// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

final class ShapeArithmeticTests: XCTestCase {
    private let square = Rect(x: 0, y: 0, width: 10, height: 10)
    private let wide = LayoutSize(width: 80, height: 40)

    /// Fitted, a geometry keeps its proportions, as large as the room allows, in the room's middle.
    func testAFittedGeometryKeepsItsProportionsInTheMiddle() {
        XCTAssertEqual(ShapeArithmetic.placement(of: square, in: wide, aspect: .fit, transform: nil), [4, 0, 0, 4, 20, 0])
    }

    /// Covering, it grows until it covers the room; stretched, each axis fills on its own; centred, it keeps its
    /// own size in the middle.
    func testTheOtherAspectsCoverStretchOrCentre() {
        XCTAssertEqual(ShapeArithmetic.placement(of: square, in: wide, aspect: .fill, transform: nil), [8, 0, 0, 8, 0, -20])
        XCTAssertEqual(ShapeArithmetic.placement(of: square, in: wide, aspect: .stretch, transform: nil), [8, 0, 0, 4, 0, 0])
        XCTAssertEqual(ShapeArithmetic.placement(of: square, in: wide, aspect: .center, transform: nil), [1, 0, 0, 1, 35, 15])
    }

    /// A line flat along one axis fits by the other alone, and stretches only along the one it has.
    func testAFlatGeometryFitsByTheAxisItHas() {
        let line = Rect(x: 0, y: 0, width: 40, height: 0)

        XCTAssertEqual(
            ShapeArithmetic.placement(of: line, in: LayoutSize(width: 80, height: 10), aspect: .fit, transform: nil),
            [2, 0, 0, 2, 0, 5])
        XCTAssertEqual(
            ShapeArithmetic.placement(of: line, in: LayoutSize(width: 80, height: 10), aspect: .stretch, transform: nil),
            [2, 0, 0, 1, 0, 5])
    }

    /// The shape's own transform moves what was placed, after it; one not of six finite numbers is none.
    func testTheShapesTransformMovesWhatWasPlaced() {
        XCTAssertEqual(
            ShapeArithmetic.placement(of: square, in: wide, aspect: .fit, transform: [1, 0, 0, 1, 5, -3]),
            [4, 0, 0, 4, 25, -3])
        XCTAssertEqual(
            ShapeArithmetic.placement(of: square, in: wide, aspect: .fit, transform: [2, 0, 0, 2, 0, 0]),
            [8, 0, 0, 8, 40, 0])
        XCTAssertEqual(
            ShapeArithmetic.placement(of: square, in: wide, aspect: .fit, transform: [1, 0, 0, .nan, 0, 0]),
            [4, 0, 0, 4, 20, 0])
    }
}
