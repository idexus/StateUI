// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

final class HostDrawingTests: XCTestCase {
    /// Each instruction lays its kind and whole numbers, its numbers and its text out in the three lists, in the
    /// order the drawing wrote them - an arc as the path the host layer works out for it.
    func testEachInstructionLaysItsValuesOutInTheThreeLists() {
        let outline = CanvasArithmetic.arc(
            in: Rect(x: 0, y: 0, width: 10, height: 20), start: 0, end: 90, clockwise: true, closed: false, wedge: false)
        let wedge = CanvasArithmetic.arc(
            in: Rect(x: 0, y: 0, width: 10, height: 20), start: 90, end: 0, clockwise: false, closed: true, wedge: true)
        let drawing = HostDrawing([
            Draw.fillColor(Color(red: 255, green: 0, blue: 0)),
            Draw.lineWidth(2),
            Draw.fillRoundedRectangle(x: 1, y: 2, width: 30, height: 40, cornerRadius: 5),
            Draw.strokeArc(x: 0, y: 0, width: 10, height: 20, startAngle: 0, endAngle: 90, clockwise: true, closed: false),
            Draw.fillArc(x: 0, y: 0, width: 10, height: 20, startAngle: 90, endAngle: 0, clockwise: false),
            Draw.text("one", x: 0, y: 0, width: 50, height: 20, horizontalAlignment: .center),
            Draw.saveState(),
            Draw.translateBy(x: 3, y: 4),
            Draw.text("two", x: 5, y: 6, width: 7, height: 8, verticalAlignment: .end),
            Draw.restoreState(),
        ])

        XCTAssertEqual(drawing.ints, [
            0, Int32(bitPattern: 0xFFFF_0000),
            3,
            13,
            11, Int32(outline.count),
            16, Int32(wedge.count),
            17, TextAlignment.center.rawValue, TextAlignment.start.rawValue, 0,
            21,
            18,
            17, TextAlignment.start.rawValue, TextAlignment.end.rawValue, 1,
            22,
        ])
        XCTAssertEqual(drawing.numbers, [
            2,
            1, 2, 30, 40, 5,
        ] + outline.flatMap(\.numbers) + wedge.flatMap(\.numbers) + [
            0, 0, 50, 20,
            3, 4,
            5, 6, 7, 8,
        ])
        XCTAssertEqual(drawing.strings, ["one", "two"])
    }

    /// An instruction whose values do not read whole - too few, not finite, not the kind asked - is left out, and
    /// the rest keep their places.
    func testAnInstructionThatDoesNotReadWholeIsLeftOut() throws {
        let short = try XCTUnwrap(DrawCommand(propValue: .values([.enumeration(12), .number(1), .number(2)])))
        let untold = try XCTUnwrap(DrawCommand(propValue: .values([.enumeration(0), .number(1)])))
        let drawing = HostDrawing([
            short,
            Draw.fillRectangle(x: .infinity, y: 0, width: 1, height: 1),
            untold,
            Draw.rotate(by: 45),
        ])

        XCTAssertEqual(drawing.ints, [19])
        XCTAssertEqual(drawing.numbers, [45])
        XCTAssertEqual(drawing.strings, [])
    }

    /// A path crosses as the count of its curves, and each curve as its kind and points - an arc as cubics; words
    /// that are no path are left out, as every record that does not read whole.
    func testAPathCrossesAsItsCurves() throws {
        let data = "M 0 0 L 10 0 A 10 10 0 0 1 20 10 Z"
        let curves = try XCTUnwrap(HostPath(svg: data)).arcsAsCubics
        let drawing = HostDrawing([Draw.fillPath(data), Draw.strokePath("not a path")])

        XCTAssertEqual(drawing.ints, [16, Int32(curves.count)])
        XCTAssertEqual(Array(drawing.numbers.prefix(6)), [0, 0, 0, 1, 10, 0])
        XCTAssertEqual(drawing.numbers[6], 2, "the arc, as a cubic")
        XCTAssertEqual(drawing.numbers.last, 4)
        XCTAssertEqual(drawing.numbers, curves.flatMap(\.numbers))
    }
}
