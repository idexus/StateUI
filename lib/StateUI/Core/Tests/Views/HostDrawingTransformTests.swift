// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import XCTest
@_spi(Host) @testable import StateUI

/// Every host draws a view's transform from this one matrix, so its pivot,
/// its order and its perspective are pinned here rather than in each host.
final class HostDrawingTransformTests: XCTestCase {
    func testTheIdentityDrawsEveryPointWhereItIs() {
        XCTAssertEqual(HostDrawingTransform.identity.matrix(width: 100, height: 60), .identity)
        XCTAssertTrue(HostDrawingTransform(pivotX: 0, pivotY: 1).isIdentity)
    }

    func testARotationTurnsClockwiseAboutTheCentre() {
        let matrix = HostDrawingTransform(rotation: 90).matrix(width: 100, height: 60)

        assert(matrix, draws: (0, 0), at: (80, -20))
        assert(matrix, draws: (100, 0), at: (80, 80))
        assert(matrix, draws: (50, 30), at: (50, 30))
    }

    func testAnAnchorMovesThePivot() {
        let matrix = HostDrawingTransform(rotation: 90, pivotX: 0, pivotY: 0)
            .matrix(width: 100, height: 60)

        assert(matrix, draws: (0, 0), at: (0, 0))
        assert(matrix, draws: (100, 0), at: (0, 100))
    }

    func testTheTranslationAppliesAfterTheTurn() {
        let matrix = HostDrawingTransform(translationX: 10, translationY: 5, rotation: 90)
            .matrix(width: 100, height: 60)

        assert(matrix, draws: (50, 30), at: (60, 35))
        assert(matrix, draws: (0, 0), at: (90, -15))
    }

    func testAScaleSizesAboutTheAnchor() {
        let matrix = HostDrawingTransform(scaleX: 2, scaleY: 0.5).matrix(width: 100, height: 60)

        assert(matrix, draws: (0, 0), at: (-50, 15))
        assert(matrix, draws: (100, 60), at: (150, 45))
    }

    func testTippingAboutTheHorizontalAxisSendsTheTopAway() {
        let matrix = HostDrawingTransform(rotationX: 55).matrix(width: 100, height: 60)
        let top = matrix.applied(to: 100, 0).x - matrix.applied(to: 0, 0).x
        let bottom = matrix.applied(to: 100, 60).x - matrix.applied(to: 0, 60).x

        XCTAssertLessThan(top, 100)
        XCTAssertGreaterThan(bottom, 100)
    }

    func testTurningAboutTheVerticalAxisSendsTheRightEdgeAway() {
        let matrix = HostDrawingTransform(rotationY: 55).matrix(width: 100, height: 60)
        let left = matrix.applied(to: 0, 60).y - matrix.applied(to: 0, 0).y
        let right = matrix.applied(to: 100, 60).y - matrix.applied(to: 100, 0).y

        XCTAssertGreaterThan(left, 60)
        XCTAssertLessThan(right, 60)
    }

    func testTheFlatDrawingThenTheTipIsTheWholeTransform() throws {
        let transform = HostDrawingTransform(
            translationX: 12, translationY: -7, rotation: 25, rotationX: 30, rotationY: -40,
            scaleX: 1.5, scaleY: 0.75, pivotX: 0.25, pivotY: 0.8)
        let (pivotX, pivotY) = (0.25 * 100, 0.8 * 60)
        let flat = HostMatrix.translation(-pivotX, -pivotY) * HostMatrix.scale(1.5, 0.75)
            * HostMatrix.rotation(degrees: 25, about: .z) * HostMatrix.translation(pivotX + 12, pivotY - 7)
        let whole = transform.matrix(width: 100, height: 60)
        let tipped = try XCTUnwrap(transform.tip(width: 100, height: 60))

        for point in [(0.0, 0.0), (100.0, 0.0), (100.0, 60.0), (0.0, 60.0), (37.0, 21.0)] {
            assert(flat * tipped, draws: point, at: whole.applied(to: point.0, point.1))
        }
        XCTAssertNil(HostDrawingTransform(translationX: 5, rotation: 30).tip(width: 100, height: 60), "nothing tips")
    }

    func testMatricesComposeInTheOrderTheyApply() {
        let turn = HostDrawingTransform(rotation: 90, pivotX: 0, pivotY: 0)
            .matrix(width: 100, height: 60)
        let move = HostDrawingTransform(translationX: 10).matrix(width: 100, height: 60)

        assert(turn * move, draws: (100, 0), at: (10, 100))
        assert(move * turn, draws: (100, 0), at: (0, 110))
    }

    func testAPlacementIsDrawnAboutItsRectanglesCentre() throws {
        let run = PlacedRun([Placement(Rect(0, 0, 100, 60), transform: .rotate(30))])
        let placements = try XCTUnwrap(HostBoundary.placements(from: run.carried))
        let drawing = try XCTUnwrap(placements.placements.first).drawing

        XCTAssertEqual(drawing.rotation, 30, accuracy: 1e-9)
        XCTAssertEqual(drawing.pivotX, 0.5)
        XCTAssertEqual(drawing.pivotY, 0.5)
    }

    private func assert(
        _ matrix: HostMatrix,
        draws point: (Double, Double),
        at expected: (Double, Double),
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let drawn = matrix.applied(to: point.0, point.1)
        XCTAssertEqual(drawn.x, expected.0, accuracy: 1e-9, file: file, line: line)
        XCTAssertEqual(drawn.y, expected.1, accuracy: 1e-9, file: file, line: line)
    }
}
