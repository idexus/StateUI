// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

/// A fill, a box's corners and outline, and a shape's lines, as every host reads what the tree sends.
final class DrawingRulesTests: XCTestCase {
    private let red = Color(red: 255, green: 0, blue: 0).propValue
    private let blue = Color(red: 0, green: 0, blue: 255).propValue

    /// A bare colour is one colour; a gradient's stops stand between 0 and 1, and it runs top to bottom where it
    /// gives no geometry; its first colour is what a line of one colour draws.
    func testABrushIsReadAsTheTreeSendsIt() {
        XCTAssertEqual(HostBrush(red), .solid(red))
        XCTAssertEqual(HostBrush(nil), .none)
        let gradient = HostBrush(.values([.enumeration(2), .numbers([]), .number(-1), red, .number(2), blue]))
        XCTAssertEqual(gradient, .linear(
            from: Point(x: 0, y: 0), to: Point(x: 0, y: 1),
            stops: [HostBrush.Stop(offset: 0, color: red), HostBrush.Stop(offset: 1, color: blue)]))
        XCTAssertEqual(gradient.firstColor, red)
    }

    /// Corners stand clockwise from the top left, never below nothing, and no corner rounds more than half its
    /// side.
    func testABoxsCornersStandClockwiseAndFitTheirRoom() {
        XCTAssertEqual(BoxArithmetic.clockwise(.corners(topLeft: 1, topRight: 2, bottomLeft: 3, bottomRight: -4)),
                       [1, 2, 0, 3])
        XCTAssertEqual(BoxArithmetic.clockwise(nil), [0, 0, 0, 0])
        XCTAssertTrue(BoxArithmetic.fitted(30, width: 100, height: 20) == (30, 10))
    }

    /// An outline is a rectangle where the tree asks none, a rounded one's radius never below nothing; it is drawn
    /// one wide where the tree gives a colour and no width, and not at all without a colour.
    func testAnOutlineIsReadAsTheTreeSendsIt() {
        XCTAssertEqual(BoxArithmetic.outline(nil), .rectangle)
        XCTAssertEqual(BoxArithmetic.outline(.values([.enumeration(1), .number(-3)])), .roundedRectangle(0))
        XCTAssertEqual(BoxArithmetic.outline(.values([.enumeration(2)])), .ellipse)
        XCTAssertEqual(BoxArithmetic.outlineWidth(stroke: red, width: nil), 1)
        XCTAssertEqual(BoxArithmetic.outlineWidth(stroke: nil, width: 4), 0)
        XCTAssertEqual(BoxArithmetic.outlineWidth(stroke: red, width: -2), 0)
    }

    /// Points are joined by lines, closed where the shape is, a point that is no number left out; dashes are
    /// stroke widths long.
    func testAShapesLinesAreItsPointsJoined() {
        let points = [Point(x: 0, y: 0), Point(x: .nan, y: 1), Point(x: 10, y: 5)]
        XCTAssertEqual(ShapeArithmetic.commands(through: points, closed: true), [0, 0, 0, 1, 10, 5, 4])
        XCTAssertEqual(ShapeArithmetic.commands(through: [], closed: false), [])
        XCTAssertEqual(ShapeArithmetic.dashLengths([2, -1], strokeWidth: 3), [6, 0])
        XCTAssertEqual(ShapeArithmetic.strokeWidth(.infinity), 0)
    }
}
