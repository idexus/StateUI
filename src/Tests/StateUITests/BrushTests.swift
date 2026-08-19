// A brush, as the typed shape it crosses in.
//
// The kind first, as the number both sides spell, then what that kind is made
// of - see Types/Brush.swift.

import StateUIWireProbe
import XCTest
@testable import StateUI

final class BrushTests: XCTestCase {
    /// One colour, and no geometry to speak of.
    func testASolidBrushIsItsKindAndItsColour() {
        XCTAssertEqual(
            Brush.solidColor(.tomato).propValue,
            .values([.enumeration(1), Color.tomato.propValue]))
    }

    /// The two points, then the stops - an offset and a colour, over and over.
    func testALinearGradientCarriesItsPointsThenItsStops() {
        let brush = Brush.linearGradient(
            [GradientStop(.gold, 0), GradientStop(.tomato, 1)],
            startPoint: Point(0, 0),
            endPoint: Point(1, 0.5))

        XCTAssertEqual(brush.propValue, .values([
            .enumeration(2),
            .numbers([0, 0, 1, 0.5]),
            .number(0), Color.gold.propValue,
            .number(1), Color.tomato.propValue,
        ]))
    }

    /// A gradient whose END POINT alone moves is a change like any other: the
    /// brush is one value, so the patch carries it whole.
    func testMovingOnlyTheEndPointSendsTheBrushAgain() {
        let renders = Renders()

        func tree(diagonal: Bool) -> Node {
            RoundRectangle()
                .fill(.linearGradient(
                    [GradientStop(.gold, 0), GradientStop(.tomato, 1)],
                    startPoint: Point(0, 0),
                    endPoint: diagonal ? Point(1, 1) : Point(1, 0)))
                .body
                .built
        }

        renders.render(tree(diagonal: false))
        let patch = renders.render(tree(diagonal: true))

        XCTAssertEqual(patch.props["fill"], .values([
            .enumeration(2),
            .numbers([0, 0, 1, 1]),
            .number(0), Color.gold.propValue,
            .number(1), Color.tomato.propValue,
        ]))
    }

    /// The centre and the radius, then the same stops.
    func testARadialGradientCarriesItsCentreAndRadius() {
        let brush = Brush.radialGradient(
            [GradientStop(.white, 0.25)],
            center: Point(0.3, 0.7),
            radius: 0.8)

        XCTAssertEqual(brush.propValue, .values([
            .enumeration(3),
            .numbers([0.3, 0.7, 0.8]),
            .number(0.25), Color.white.propValue,
        ]))
    }

    /// A stop written with a themed colour picks its half like any other, so
    /// what crosses is one gradient - and the view that wrote it is rebuilt
    /// when the system flips.
    func testAThemedStopPicksItsHalfLikeAnyOtherColour() {
        func brush() -> PropValue {
            Brush.solidColor(Color(light: .white, dark: .black)).propValue
        }

        XCTAssertEqual(brush(), .values([
                .enumeration(1), Color.white.propValue]))

        withTheme(.dark) {
            XCTAssertEqual(brush(), .values([
                .enumeration(1), Color.black.propValue]))
        }
    }

    /// A list of values nests, which is the whole of what the tag is for.
    func testAListOfValuesCrossesAsItsParts() {
        var out: [UInt8] = []
        out.value(.values([.number(1), .bool(true)]))

        XCTAssertEqual(out, [9, 2, 0, 3, 0, 0, 0, 0, 0, 0, 240, 63, 2])
    }
}
