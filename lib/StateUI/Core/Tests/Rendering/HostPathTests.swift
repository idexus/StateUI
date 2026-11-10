// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
import XCTest

@MainActor
final class HostPathTests: XCTestCase {
    func testRelativeCommandsAndRepeatedMovePairsBecomeAbsoluteCommands() throws {
        let path = try XCTUnwrap(HostPath(svg: "M 10,20 30,40 l 5,-10 h 10 v 5 z"))

        XCTAssertEqual(path.commands, [
            .move(Point(10, 20)),
            .line(Point(30, 40)),
            .line(Point(35, 30)),
            .line(Point(45, 30)),
            .line(Point(45, 35)),
            .close,
        ])
    }

    func testSmoothCurvesReflectThePreviousControlPoint() throws {
        let path = try XCTUnwrap(HostPath(
            svg: "M0 0 C10 0 20 10 30 10 S50 20 60 10 Q70 0 80 10 T100 10"))

        XCTAssertEqual(path.commands, [
            .move(.zero),
            .cubic(control1: Point(10, 0), control2: Point(20, 10), end: Point(30, 10)),
            .cubic(control1: Point(40, 10), control2: Point(50, 20), end: Point(60, 10)),
            .quadratic(control: Point(70, 0), end: Point(80, 10)),
            .quadratic(control: Point(90, 20), end: Point(100, 10)),
        ])
    }

    func testArcFlagsAndExponentNumbersAreParsedWithoutLocale() throws {
        let path = try XCTUnwrap(HostPath(svg: "M1e1 -.5 A 20 10 30 1 0 50 60"))

        XCTAssertEqual(path.commands, [
            .move(Point(10, -0.5)),
            .arc(
                radiusX: 20,
                radiusY: 10,
                rotation: 30,
                largeArc: true,
                sweep: false,
                end: Point(50, 60)),
        ])
    }

    /// An arc's two flags are one digit each, so a path written without spaces - as minified icons are - reads the
    /// flags and the end apart.
    func testArcFlagsWrittenTogetherAreReadOneDigitEach() throws {
        XCTAssertEqual(try XCTUnwrap(HostPath(svg: "M0 0a1 1 0 011 1")).commands, [
            .move(.zero),
            .arc(radiusX: 1, radiusY: 1, rotation: 0, largeArc: false, sweep: true, end: Point(1, 1)),
        ])
        XCTAssertEqual(try XCTUnwrap(HostPath(svg: "M0 0A5 5 0 1110 10,5 5 0 0,0 0 0")).commands, [
            .move(.zero),
            .arc(radiusX: 5, radiusY: 5, rotation: 0, largeArc: true, sweep: true, end: Point(10, 10)),
            .arc(radiusX: 5, radiusY: 5, rotation: 0, largeArc: false, sweep: false, end: .zero),
        ])
        XCTAssertNil(HostPath(svg: "M0 0a1 1 0 211 1"), "a flag is 0 or 1")
    }

    func testMalformedOrNonFinitePathIsRejectedAsAWhole() {
        XCTAssertNil(HostPath(svg: "M 0 0 L 10"))
        XCTAssertNil(HostPath(svg: "M 0 0 A 10 10 0 2 0 20 20"))
        XCTAssertNil(HostPath(svg: "M 1e999 0"))
        XCTAssertNil(HostPath(svg: "M 0 0 X 1 1"))
    }

    /// A half turn of a circle is two quarter-turn curves that end exactly where the arc does, the first at
    /// the circle's side; every other command passes as it is.
    func testAnArcIsDrawnAsQuarterTurnCurves() throws {
        let path = try XCTUnwrap(HostPath(svg: "M 0 0 A 1 1 0 0 1 2 0 L 3 0"))
        let drawn = path.arcsAsCubics

        XCTAssertEqual(drawn.count, 4)
        XCTAssertEqual(drawn.first, HostCurveCommand.move(Point(0, 0)))
        guard case .cubic(_, _, let middle) = drawn[1], case .cubic(_, _, let end) = drawn[2] else {
            return XCTFail("\(drawn)")
        }
        XCTAssertEqual(middle.x, 1, accuracy: 1e-9)
        XCTAssertEqual(abs(middle.y), 1, accuracy: 1e-9)
        XCTAssertEqual(end, Point(2, 0))
        XCTAssertEqual(drawn.last, .line(Point(3, 0)))
    }
}
