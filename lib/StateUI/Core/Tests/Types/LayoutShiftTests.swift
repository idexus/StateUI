// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// How far a view stands from where its arithmetic puts it: measured from where it was shown, laid back over a pose,
/// and decaying to nothing under a motion.
final class LayoutShiftTests: XCTestCase {
    /// A SHIFT LAID OVER THE NEW POSE SHOWS THE VIEW WHERE IT STOOD: place, size, opacity, shade and a transform as
    /// a view draws it - moved, turned and sized, a slant dropped, as no view shows one.
    func testAShiftShowsTheViewWhereItStood() {
        let shown = Placement(
            Rect(10, 20, 100, 60), transform: .scale(1.5).rotate(30).skew(10, 0).translate(4, -6), opacity: 0.4,
            shade: 0.2, zIndex: 3)
        let pose = Placement(Rect(200, 40, 80, 80), transform: .rotate(-20), opacity: 1, shade: 0.5, zIndex: 7)

        let laid = LayoutShift(from: shown, to: pose).applied(to: pose)

        XCTAssertEqual(laid.bounds, shown.bounds)
        assertTransform(laid.transform, shown.transform.drawn)
        XCTAssertEqual(laid.opacity, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(laid.shade, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(laid.zIndex, 7, "the order is the pose's at once")
    }

    /// NO SHIFT IS THE POSE ITSELF, a slant it holds included.
    func testNoShiftIsThePose() {
        let pose = Placement(Rect(5, 5, 50, 50), transform: .skew(20, 0).scale(2), opacity: 0.7)

        let laid = LayoutShift.none.applied(to: pose)

        XCTAssertEqual(laid.bounds, pose.bounds)
        assertTransform(laid.transform, pose.transform)
        XCTAssertEqual(laid.opacity, 0.7)
    }

    /// A TURN GOES THE SHORT WAY: from 170 degrees to -170 is twenty degrees on, not three hundred and forty back.
    func testATurnGoesTheShortWay() {
        let shift = LayoutShift(
            from: Placement(Rect(0, 0, 10, 10), transform: .rotate(170)),
            to: Placement(Rect(0, 0, 10, 10), transform: .rotate(-170)))

        XCTAssertEqual(shift.lanes[LayoutShift.turn], -20, accuracy: 0.000_001)
    }

    /// A VIEW JOINING FADES IN: where it lands, from nothing to its own opacity.
    func testAViewJoiningFadesIn() {
        let pose = Placement(Rect(0, 0, 10, 10), opacity: 0.8)

        let laid = LayoutShift.joining(pose).applied(to: pose)

        XCTAssertEqual(laid.bounds, pose.bounds)
        XCTAssertEqual(laid.opacity, 0)
    }

    /// A SHADE THE LAYOUT DRAWS NONE OF IS NOT BLENDED: a pose without one keeps it, whatever was shown.
    func testAnUnshadedPoseKeepsItsShade() {
        let shown = Placement(Rect(0, 0, 10, 10), shade: 0.6)
        let pose = Placement(Rect(0, 0, 10, 10), shade: Placement.unshaded)

        XCTAssertEqual(LayoutShift(from: shown, to: pose).applied(to: pose).shade, Placement.unshaded)
    }

    private func assertTransform(
        _ transform: ViewTransform, _ expected: ViewTransform, file: StaticString = #filePath, line: UInt = #line
    ) {
        for (got, wanted) in [
            (transform.a, expected.a), (transform.b, expected.b), (transform.c, expected.c), (transform.d, expected.d),
            (transform.tx, expected.tx), (transform.ty, expected.ty),
        ] {
            XCTAssertEqual(got, wanted, accuracy: 0.000_001, file: file, line: line)
        }
    }
}
