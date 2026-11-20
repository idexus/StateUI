// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost

/// How far a child stands from where its layout puts it: measured from where it was shown, laid back over a place.
@MainActor
final class LayoutShiftTests: XCTestCase {
    /// A placement as the host is handed it.
    private func host(_ placement: Placement) -> HostPlacement {
        HostBoundary.placement(of: placement)
    }

    /// A SHIFT LAID OVER THE NEW PLACE SHOWS THE CHILD WHERE IT STOOD: place, size, opacity, shade and a transform
    /// as a view draws it - moved, turned and sized.
    func testAShiftShowsTheViewWhereItStood() {
        let shown = host(Placement(
            Rect(x: 10, y: 20, width: 100, height: 60), transform: .scale(1.5).rotate(30).translate(4, -6), opacity: 0.4, shade: 0.2,
            zIndex: 3))
        let place = host(Placement(Rect(x: 200, y: 40, width: 80, height: 80), transform: .rotate(-20), opacity: 1, shade: 0.5, zIndex: 7))

        let laid = LayoutShift(from: shown, to: place).applied(to: place)

        XCTAssertEqual(laid.bounds, shown.bounds)
        XCTAssertEqual(laid.translationX, shown.translationX, accuracy: 0.000_001)
        XCTAssertEqual(laid.translationY, shown.translationY, accuracy: 0.000_001)
        XCTAssertEqual(laid.rotation, shown.rotation, accuracy: 0.000_001)
        XCTAssertEqual(laid.scaleX, shown.scaleX, accuracy: 0.000_001)
        XCTAssertEqual(laid.scaleY, shown.scaleY, accuracy: 0.000_001)
        XCTAssertEqual(laid.opacity, 0.4, accuracy: 0.000_001)
        XCTAssertEqual(laid.shade, 0.2, accuracy: 0.000_001)
        XCTAssertEqual(laid.zIndex, 7, "the order is the place's at once")
    }

    /// NO SHIFT IS THE PLACE ITSELF.
    func testNoShiftIsThePlace() {
        let place = host(Placement(Rect(x: 5, y: 5, width: 50, height: 50), transform: .scale(2), opacity: 0.7))

        XCTAssertEqual(LayoutShift.none.applied(to: place), place)
        XCTAssertEqual(LayoutShift(from: place, to: place), .none)
    }

    /// A TURN GOES THE SHORT WAY: from 170 degrees to -170 is twenty degrees on, not three hundred and forty back.
    func testATurnGoesTheShortWay() {
        let shift = LayoutShift(
            from: host(Placement(Rect(x: 0, y: 0, width: 10, height: 10), transform: .rotate(170))),
            to: host(Placement(Rect(x: 0, y: 0, width: 10, height: 10), transform: .rotate(-170))))

        XCTAssertEqual(shift.lanes[LayoutShift.turn], -20, accuracy: 0.000_001)
    }

    /// A CHILD JOINING FADES IN: where it lands, from nothing to its own opacity.
    func testAViewJoiningFadesIn() {
        let place = host(Placement(Rect(x: 0, y: 0, width: 10, height: 10), opacity: 0.8))

        let laid = LayoutShift.joining(place).applied(to: place)

        XCTAssertEqual(laid.bounds, place.bounds)
        XCTAssertEqual(laid.opacity, 0)
    }

    /// A SHADE THE LAYOUT DRAWS NONE OF IS NOT BLENDED: a place without one keeps it, whatever was shown.
    func testAnUnshadedPlaceKeepsItsShade() {
        let shown = host(Placement(Rect(x: 0, y: 0, width: 10, height: 10), shade: 0.6))
        let place = host(Placement(Rect(x: 0, y: 0, width: 10, height: 10), shade: Placement.unshaded))

        XCTAssertEqual(LayoutShift(from: shown, to: place).applied(to: place).shade, HostPlacement.unshaded)
    }
}
