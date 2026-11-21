// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// Where a placing run stands a ZStack's children, and in what order it draws them.
@MainActor
final class PlacingRunTests: XCTestCase {
    private func placed(z: Int, width: Double = 10, opacity: Double = 1, shade: Double = 0) -> HostPlacement {
        HostPlacement(
            bounds: Rect(x: 1, y: 2, width: width, height: -4), translationX: 0, translationY: 0, rotation: 0,
            scaleX: 1, scaleY: 1, opacity: opacity, zIndex: z, shade: shade)
    }

    /// Children are drawn back to front by their z-index, the earlier first among equals, those the run places
    /// none of after them - and last, in that order, those a shared entry draws in front.
    func testChildrenAreDrawnByTheirZIndexThenInTheirOrder() {
        let placements = [placed(z: 2), placed(z: 0), placed(z: 2)]
        XCTAssertEqual(DrawingOrder.of(5, placedBy: placements, inFront: { _ in false }), [1, 0, 2, 3, 4])
        XCTAssertEqual(DrawingOrder.of(2, placedBy: [], inFront: { _ in false }), [0, 1])
        XCTAssertEqual(DrawingOrder.of(5, placedBy: placements, inFront: { [1, 3].contains($0) }), [0, 2, 4, 1, 3])
    }

    /// A placed child has no size below nothing, and its opacity stands between 0 and 1.
    func testAPlaceHasNoSizeBelowNothing() {
        let run = HostPlacementRun(placements: [placed(z: 0, width: -3)], direction: .leftToRight)
        XCTAssertEqual(run.place(of: 0, in: Rect(x: 0, y: 0, width: 100, height: 50)), Rect(x: 1, y: 2, width: 0, height: 0))
        XCTAssertEqual([placed(z: 0, opacity: 1.5), placed(z: 0, opacity: -1)].map(\.drawnOpacity), [1, 0])
    }

    /// A run standing right to left is the mirror of the run as written: each place turned about the room's middle,
    /// its move along and its turn the other way, its size, its move down and its scale as they are.
    func testARunRightToLeftIsTheMirrorOfTheRunAsWritten() {
        let placement = HostPlacement(
            bounds: Rect(x: 10, y: 5, width: 50, height: 20), translationX: 7, translationY: 3, rotation: 30,
            scaleX: 2, scaleY: 0.5, opacity: 1, zIndex: 0, shade: 0)
        let room = Rect(x: 0, y: 0, width: 200, height: 100)
        let written = HostPlacementRun(placements: [placement], direction: .leftToRight)
        let mirrored = HostPlacementRun(placements: [placement], direction: .rightToLeft)

        XCTAssertEqual(written.place(of: 0, in: room), Rect(x: 10, y: 5, width: 50, height: 20))
        XCTAssertEqual(mirrored.place(of: 0, in: room), Rect(x: 140, y: 5, width: 50, height: 20))
        XCTAssertEqual(mirrored.writtenPlace(of: 0), Rect(x: 10, y: 5, width: 50, height: 20))
        XCTAssertEqual(written.drawing(of: 0), HostDrawingTransform(
            translationX: 7, translationY: 3, rotation: 30, scaleX: 2, scaleY: 0.5))
        XCTAssertEqual(mirrored.drawing(of: 0), HostDrawingTransform(
            translationX: -7, translationY: 3, rotation: -30, scaleX: 2, scaleY: 0.5))
    }

    /// A placement is drawn about its rectangle's center, turned as the run says.
    func testAPlacementIsDrawnAboutItsRectanglesCenter() throws {
        let run = PlacedRun([Placement(Rect(x: 0, y: 0, width: 100, height: 60), transform: .rotate(30))])
        let drawing = HostPlacementRun(placements: HostBoundary.placements(of: run), direction: .leftToRight)
            .drawing(of: 0)

        XCTAssertEqual(drawing.rotation, 30, accuracy: 1e-9)
        XCTAssertEqual(drawing.pivotX, 0.5)
        XCTAssertEqual(drawing.pivotY, 0.5)
    }

    /// A card's shade is drawn between nothing and whole.
    func testAShadeIsDrawnWithinWhole() {
        XCTAssertEqual(placed(z: 0, shade: -0.2).drawnShade, 0)
        XCTAssertEqual(placed(z: 0, shade: 1.5).drawnShade, 1)
        XCTAssertEqual(placed(z: 0, shade: 0.4).drawnShade, 0.4)
    }
}
