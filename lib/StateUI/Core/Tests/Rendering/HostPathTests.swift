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

    /// A path that ends on a command before its numbers, or inside a command's group, is rejected as a whole.
    func testACommandWithoutItsNumbersRejectsThePath() {
        for command in "MmLlHhVvCcSsQqTtAa" {
            XCTAssertNil(HostPath(svg: "\(command)"), "\(command)")
            XCTAssertNil(HostPath(svg: "M0 0 \(command)"), "\(command)")
            XCTAssertNil(HostPath(svg: "M0 0 z \(command)"), "\(command)")
        }
        for incomplete in ["M0", "M0 0 L1", "M0 0 H1 V", "M0 0 C1 1 2 2 3", "M0 0 S1 1 2", "M0 0 Q1 1",
                           "M0 0 T1", "M0 0 A1 1 0 0 1 2", "M0 0 L1 1 2"] {
            XCTAssertNil(HostPath(svg: incomplete), incomplete)
        }
    }

    /// Radii of any size draw an arc of numbers ending where the arc does: radii too small to reach are scaled up
    /// as any are - a millionth or a 1e-300 draws the same half circle - and radii vastly past the chord draw it.
    func testArcsOfAnyRadiiDrawNumbers() throws {
        func numbers(_ curves: [HostCurveCommand]) -> [Double] {
            curves.flatMap { command -> [Double] in
                switch command {
                case .cubic(let a, let b, let c): [a.x, a.y, b.x, b.y, c.x, c.y]
                case .line(let p), .move(let p): [p.x, p.y]
                default: []
                }
            }
        }
        func drawn(_ radius: Double, to end: Point, rotation: Double = 0, large: Bool = false, sweep: Bool = true)
            -> [HostCurveCommand] {
            HostPath.arc(from: .zero, to: end, radiusX: radius, radiusY: radius / 2, rotation: rotation,
                         largeArc: large, sweep: sweep)
        }
        var wrong: [String] = []
        for radius in [1e-300, 1e-200, 1e-6, 1, 1e6, 1e200, 1e300, Double.greatestFiniteMagnitude, 5e-324] {
            for end in [Point(2, 0), Point(2, 2), Point(0, 2), Point(-1e-3, 5)] {
                for (rotation, large, sweep) in [(0.0, false, true), (45, true, false), (1e300, true, true)] {
                    let curves = drawn(radius, to: end, rotation: rotation, large: large, sweep: sweep)
                    let ending: Point? = switch curves.last {
                    case .cubic(_, _, let at), .line(let at): at
                    default: nil
                    }
                    if !numbers(curves).allSatisfy(\.isFinite) || ending != end {
                        wrong.append("\(radius) to \(end), \(rotation) \(large) \(sweep): \(curves)")
                    }
                }
            }
        }
        XCTAssertEqual(wrong, [])
        let (tiny, small) = (numbers(drawn(1e-300, to: Point(2, 0))), numbers(drawn(1e-6, to: Point(2, 0))))
        XCTAssertEqual(tiny.count, small.count)
        for (one, other) in zip(tiny, small) { XCTAssertEqual(one, other, accuracy: 1e-9, "scaled up to just reach") }
        XCTAssertEqual(drawn(1e300, to: Point(2, 0)), [.line(Point(2, 0))], "flatter than any display shows")
        XCTAssertNotNil(HostPath(svg: "M0 0 A1e-200 1e-200 0 0 1 2 2")?.arcsAsCubics)
    }

    /// An arc whose radii stand far past its chord is the chord the short way round and the whole ellipse less the
    /// chord the long way: fitted to a room by its frame, as a host fits a shape, the long one is the ellipse.
    func testALargeArcOfRadiiFarPastItsChordIsTheWholeEllipse() throws {
        func sampled(_ curves: [HostCurveCommand]) -> [Point] {
            var (at, points) = (Point.zero, [Point.zero])
            for curve in curves {
                switch curve {
                case .cubic(let a, let b, let end):
                    for step in 1...16 {
                        let t = Double(step) / 16, s = 1 - t
                        points.append(Point(
                            s * s * s * at.x + 3 * s * s * t * a.x + 3 * s * t * t * b.x + t * t * t * end.x,
                            s * s * s * at.y + 3 * s * s * t * a.y + 3 * s * t * t * b.y + t * t * t * end.y))
                    }
                    at = end
                case .line(let end):
                    (at, points) = (end, points + [end])
                default: XCTFail("\(curve)")
                }
            }
            return points
        }
        for (radius, chord) in [(1_000.0, 1e-6), (1e10, 2), (1e100, 2), (1e300, 1)] {
            for (squash, rotation) in [(1.0, 0.0), (0.5, 0), (0.5, 90)] {
                for sweep in [false, true] {
                    let named = "r \(radius) chord \(chord) squash \(squash) rotation \(rotation) sweep \(sweep)"
                    func drawn(large: Bool) -> [Point] {
                        sampled(HostPath.arc(from: .zero, to: Point(chord, 0), radiusX: radius, radiusY: radius * squash,
                                             rotation: rotation, largeArc: large, sweep: sweep))
                    }
                    let short = drawn(large: false)
                    XCTAssertLessThanOrEqual(short.map { abs($0.y) }.max() ?? .infinity, chord * 1e-6, "short: \(named)")

                    let long = drawn(large: true)
                    let (xs, ys) = (long.map(\.x), long.map(\.y))
                    let (width, height) = (xs.max()! - xs.min()!, ys.max()! - ys.min()!)
                    let across = rotation == 0 ? squash : 1 / squash
                    XCTAssertEqual(height / width, across, accuracy: 1e-3, "the long way's frame: \(named)")
                    let center = Point((xs.max()! + xs.min()!) / 2, (ys.max()! + ys.min()!) / 2)
                    let off = long.map { point in
                        abs(hypot((point.x - center.x) / (width / 2), (point.y - center.y) / (height / 2)) - 1)
                    }
                    XCTAssertLessThan(off.max()!, 1e-3, "every point on the ellipse fitted to the room: \(named)")
                }
            }
        }
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
