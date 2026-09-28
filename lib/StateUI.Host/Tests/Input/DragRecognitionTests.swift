// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

final class DragRecognitionTests: XCTestCase {
    /// A press is a drag once it moved more than the distance along either axis: it starts, and each move after is
    /// measured from where the press went down.
    func testAPressBecomesADragOnlyPastTheSystemsDistance() {
        var drag = DragRecognition(distance: .eachAxis(x: 4, y: 3))
        drag.pressed(at: Point(x: 100, y: 100))

        XCTAssertEqual(drag.moved(to: Point(x: 104, y: 97)), [], "at the distance, still a press")
        XCTAssertFalse(drag.isDragging)
        XCTAssertEqual(drag.moved(to: Point(x: 102, y: 96)), [.drag(.started, x: 0, y: 0), .drag(.running, x: 2, y: -4)],
                       "past it down, though not across")
        XCTAssertTrue(drag.isDragging)
        XCTAssertEqual(drag.moved(to: Point(x: 101, y: 100)), [.drag(.running, x: 1, y: 0)], "back near, still dragging")
        XCTAssertEqual(drag.ended(letGo: true), .drag(.completed, x: 1, y: 0))
        XCTAssertFalse(drag.isDragging)
    }

    /// Where the platform measures a radius, the press is a drag once it moved more than it any way.
    func testARadiusIsMeasuredAnyWay() {
        var drag = DragRecognition(distance: .radius(5))
        drag.pressed(at: Point(x: 0, y: 0))

        XCTAssertEqual(drag.moved(to: Point(x: 3, y: 4)), [], "five away is still the press")
        XCTAssertEqual(drag.moved(to: Point(x: 4, y: 4)).first, .drag(.started, x: 0, y: 0))
    }

    /// A press that never became a drag ends with nothing; one the platform takes away is cancelled; a move with no
    /// press, or after one ended, is nothing; the next press starts anew.
    func testAPressEndsItsDragAndOnlyItsOwn() {
        var drag = DragRecognition(distance: .eachAxis(x: 4, y: 4))
        XCTAssertEqual(drag.moved(to: Point(x: 50, y: 50)), [], "no press")

        drag.pressed(at: Point(x: 0, y: 0))
        _ = drag.moved(to: Point(x: 2, y: 2))
        XCTAssertNil(drag.ended(letGo: true), "a press, never a drag")
        XCTAssertEqual(drag.moved(to: Point(x: 20, y: 0)), [], "after the press let go")

        drag.pressed(at: Point(x: 10, y: 10))
        XCTAssertEqual(drag.moved(to: Point(x: 30, y: 10)).last, .drag(.running, x: 20, y: 0), "from the new press")
        XCTAssertEqual(drag.ended(letGo: false), .drag(.canceled, x: 20, y: 0))
    }
}
