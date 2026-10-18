// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest

@testable import StateUI

/// A curve of one's own: half way between the two keyframes around the place, wherever it is.
private struct Halfway: LayoutInterpolation {
    var reach: Int { 0 }

    func value(at place: Double, segment: Int, knots: [Double], values: [Double]) -> Double {
        (values[segment] + values[segment + 1]) / 2
    }
}

/// The curves through a layout's keyframes, and the poses blended along them view by view.
final class LayoutInterpolationTests: XCTestCase {
    private let knots = [0.0, 1, 2, 3]

    /// The number at `place` of `curve` through `values` at `knots`, the window cut as the engine cuts it.
    private func value(_ curve: LayoutCurve, at place: Double, _ values: [Double]) -> Double {
        let segment = min(knots.lastIndex { $0 <= place } ?? 0, knots.count - 2)
        let (first, last) = (max(segment - curve.reach, 0), min(segment + 1 + curve.reach, knots.count - 1))
        return curve.value(
            at: place, segment: segment - first, knots: Array(knots[first...last]),
            values: Array(values[first...last]))
    }

    // MARK: - The curves

    /// EVERY CURVE PASSES THROUGH EACH KEYFRAME: a pose at a keyframe is the arithmetic's own.
    func testEveryCurvePassesThroughEachKeyframe() {
        let values = [0.0, 4, -2, 7]
        for curve in [LayoutCurve.linear, .catmullRom, .catmullRom(tension: 0.5), .monotone] {
            for (index, knot) in knots.dropLast().enumerated() {
                XCTAssertEqual(value(curve, at: knot, values), values[index], accuracy: 1e-12, "\(curve) at \(knot)")
            }
            XCTAssertEqual(value(curve, at: 3, values), 7, accuracy: 1e-12, "\(curve) at the last")
        }
    }

    /// A STRAIGHT RUN STAYS STRAIGHT under every curve: evenly spaced, evenly paced.
    func testAStraightRunStaysStraight() {
        let values = [0.0, 10, 20, 30]
        for curve in [LayoutCurve.linear, .catmullRom, .monotone] {
            for place in stride(from: 0.0, through: 3, by: 0.25) {
                XCTAssertEqual(value(curve, at: place, values), place * 10, accuracy: 1e-9, "\(curve) at \(place)")
            }
        }
    }

    /// THE CATMULL-ROM CURVE IS SHAPED BY THE NEIGHBOURS: through 0, 10 and 40 it starts slower than the straight
    /// line; held at a tension of 1 it slows to a stop at each keyframe.
    func testTheCatmullRomCurveIsShapedByTheNeighbours() {
        let values = [0.0, 10, 40, 90]
        XCTAssertEqual(value(.linear, at: 0.5, values), 5, accuracy: 1e-12)
        XCTAssertEqual(value(.catmullRom, at: 0.5, values), 3.75, accuracy: 1e-12)
        XCTAssertEqual(value(.catmullRom(tension: 1), at: 0.25, values), 10 * (3 * 0.0625 - 2 * 0.015625), accuracy: 1e-12)
    }

    /// THE MONOTONE CURVE NEVER PASSES ITS KEYFRAMES where Catmull-Rom swings past one: from a rest at 0 up to a
    /// rest at 1, it never dips below nought nor rises above one.
    func testTheMonotoneCurveNeverPassesItsKeyframes() {
        let values = [0.0, 0, 1, 1]
        let places = stride(from: 0.0, through: 3, by: 0.05)

        XCTAssertLessThan(places.map { value(.catmullRom, at: $0, values) }.min() ?? 0, -0.001, "Catmull-Rom dips")
        for place in places {
            let monotone = value(.monotone, at: place, values)
            XCTAssertGreaterThanOrEqual(monotone, 0, "at \(place)")
            XCTAssertLessThanOrEqual(monotone, 1, "at \(place)")
        }
    }

    /// A TENSION OUTSIDE 0...1 IS HELD INSIDE IT.
    func testATensionOutsideItsRangeIsHeldInside() {
        XCTAssertEqual(LayoutCurve.catmullRom(tension: 3), .catmullRom(tension: 1))
        XCTAssertEqual(LayoutCurve.catmullRom(tension: -1), .catmullRom)
        XCTAssertEqual(LayoutCurve.catmullRom(tension: .nan), .catmullRom)
    }

    // MARK: - The poses blended

    /// THE BOUNDS GO ALONG THE CURVE, view by view in the views' order.
    func testTheBoundsGoAlongTheCurve() {
        let at0 = [Placement(Rect(0, 0, 10, 10)), Placement(Rect(100, 0, 10, 10))]
        let at1 = [Placement(Rect(100, 50, 30, 10)), Placement(Rect(0, 0, 10, 10))]

        let blended = LayoutBlend.blend([at0, at1], at: 0.25, segment: 0, knots: [0, 1], curve: .linear)
        XCTAssertEqual(blended[0].bounds, Rect(25, 12.5, 15, 10))
        XCTAssertEqual(blended[1].bounds, Rect(75, 0, 10, 10))
    }

    /// A TURN GOES THE SHORT WAY from keyframe to keyframe: 170° to -170° passes 180°, not nought.
    func testATurnGoesTheShortWay() {
        let at0 = [Placement(Rect(0, 0, 10, 10), transform: .rotate(170))]
        let at1 = [Placement(Rect(0, 0, 10, 10), transform: .rotate(-170))]

        let blended = LayoutBlend.blend([at0, at1], at: 0.5, segment: 0, knots: [0, 1], curve: .linear)
        XCTAssertEqual(abs(blended[0].transform.rotation), 180, accuracy: 1e-9)
    }

    /// A TRANSFORM AT EVERY KEYFRAME STAYS AS IT IS, not taken apart and put together a rounding off.
    func testOneTransformAtEveryKeyframeStaysAsItIs() {
        let transform = ViewTransform.rotate(33).scale(0.7)
        let at0 = [Placement(Rect(0, 0, 10, 10), transform: transform)]
        let at1 = [Placement(Rect(50, 0, 10, 10), transform: transform)]

        let blended = LayoutBlend.blend([at0, at1], at: 0.3, segment: 0, knots: [0, 1], curve: .linear)
        XCTAssertEqual(blended[0].transform, transform)
    }

    /// OPACITY AND SHADE STAY INSIDE 0...1 where a cubic swings past its keyframes, and a layout with no shade stays
    /// without one.
    func testOpacityAndShadeStayInside() {
        let runs = [0.0, 1, 1, 0].map { opacity in
            [Placement(Rect(0, 0, 10, 10), opacity: opacity, shade: opacity)]
        }
        let curve = LayoutCurve.catmullRom
        XCTAssertGreaterThan(curve.value(at: 1.5, segment: 1, knots: knots, values: [0, 1, 1, 0]), 1, "it swings past")

        let blended = LayoutBlend.blend(runs, at: 1.5, segment: 1, knots: knots, curve: curve)
        XCTAssertEqual(blended[0].opacity, 1)
        XCTAssertEqual(blended[0].shade, 1)

        let unshaded = [[Placement(Rect.zero, shade: PackedPlacement.unshaded)],
                        [Placement(Rect.zero, shade: PackedPlacement.unshaded)]]
        XCTAssertEqual(
            LayoutBlend.blend(unshaded, at: 0.5, segment: 0, knots: [0, 1], curve: .linear)[0].shade,
            PackedPlacement.unshaded)
    }

    /// THE DRAWING ORDER SWAPS AS THE VIEWS' NUMBERS CROSS: a view rising from 0 to 2 past one standing at 1 is drawn
    /// under it before the middle, over it after.
    func testTheDrawingOrderSwapsAsTheNumbersCross() {
        let at0 = [Placement(Rect.zero, zIndex: 0), Placement(Rect.zero, zIndex: 1)]
        let at1 = [Placement(Rect.zero, zIndex: 2), Placement(Rect.zero, zIndex: 1)]

        let before = LayoutBlend.blend([at0, at1], at: 0.25, segment: 0, knots: [0, 1], curve: .linear)
        let after = LayoutBlend.blend([at0, at1], at: 0.75, segment: 0, knots: [0, 1], curve: .linear)
        XCTAssertLessThan(before[0].zIndex, before[1].zIndex)
        XCTAssertGreaterThan(after[0].zIndex, after[1].zIndex)
    }

    /// A CURVE OF ONE'S OWN is the blend's curve as the library's are.
    func testACurveOfOnesOwnBlends() {
        let at0 = [Placement(Rect(0, 0, 10, 10))]
        let at1 = [Placement(Rect(80, 0, 10, 10))]

        let blended = LayoutBlend.blend([at0, at1], at: 0.1, segment: 0, knots: [0, 1], curve: Halfway())
        XCTAssertEqual(blended[0].bounds.x, 40)
    }
}
