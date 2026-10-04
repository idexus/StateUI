// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
import XCTest

/// A canvas's drawing as every host drawing in Swift replays it: its instructions read from their records, the pen
/// they set, and its arcs as curves.
@MainActor
final class CanvasRulesTests: XCTestCase {
    /// Each instruction reads as what `Draw` wrote; a record that does not read whole is left out.
    func testAnInstructionReadsAsDrawWroteIt() throws {
        let broken = try XCTUnwrap(DrawCommand(propValue: .values([.enumeration(6), .number(1)])))
        let drawing = [
            Draw.fillColor(.red), Draw.lineWidth(3),
            Draw.fillRoundedRectangle(x: 1, y: 2, width: 30, height: 40, cornerRadius: 5),
            Draw.text("Go", x: 0, y: 0, width: 90, height: 30, horizontalAlignment: .center),
            Draw.strokeArc(x: 0, y: 0, width: 10, height: 10, startAngle: 0, endAngle: 90, clockwise: true, closed: false),
            broken, Draw.saveState(), Draw.rotate(by: 45), Draw.restoreState(),
        ]

        XCTAssertEqual(CanvasInstruction.instructions(drawing), [
            .fillColor(Color.red.propValue), .lineWidth(3),
            .fillRoundedRectangle(Rect(x: 1, y: 2, width: 30, height: 40), radius: 5),
            .text("Go", in: Rect(x: 0, y: 0, width: 90, height: 30), horizontal: .center, vertical: .start),
            .strokeArc(Rect(x: 0, y: 0, width: 10, height: 10), start: 0, end: 90, clockwise: true, closed: false),
            .saveState, .rotate(degrees: 45), .restoreState,
        ])
    }

    /// A setting holds until the next of its kind; a saved state is put back whole.
    func testASettingHoldsTillChangedAndASavedStateComesBack() {
        var pen = CanvasPen()
        XCTAssertTrue(pen.take(.fillColor(Color.red.propValue)))
        XCTAssertTrue(pen.take(.lineWidth(-2)))
        XCTAssertEqual(pen.lineWidth, 0, "never below nothing")
        XCTAssertTrue(pen.take(.saveState))
        XCTAssertTrue(pen.take(.opacity(2)))
        XCTAssertTrue(pen.take(.fillColor(Color.blue.propValue)))
        XCTAssertEqual(pen.alpha, 1, "never past whole")
        XCTAssertTrue(pen.take(.restoreState))
        XCTAssertEqual(pen.fill, Color.red.propValue)
        XCTAssertEqual(pen.savedDepth, 0)
        XCTAssertFalse(pen.take(.strokeEllipse(Rect(x: 0, y: 0, width: 1, height: 1))), "a drawing is no setting")
    }

    /// An arc begins and ends where its angles say, clockwise down from the right; a whole turn draws the ellipse
    /// whole; a wedge runs from the middle and closes.
    func testAnArcRunsBetweenItsAnglesAsCurves() throws {
        let room = Rect(x: 0, y: 0, width: 100, height: 100)
        let quarter = CanvasArithmetic.arc(in: room, start: 0, end: 90, clockwise: true, closed: false, wedge: false)
        XCTAssertEqual(quarter.first, .move(Point(x: 100, y: 50)))
        guard case .cubic(_, _, let end)? = quarter.last else { return XCTFail("a quarter is a curve") }
        XCTAssertEqual(end.x, 50, accuracy: 1e-9)
        XCTAssertEqual(end.y, 100, accuracy: 1e-9)

        let whole = CanvasArithmetic.arc(in: room, start: 0, end: 360, clockwise: true, closed: false, wedge: false)
        guard case .cubic(_, _, let back)? = whole.last else { return XCTFail("a whole turn is curves") }
        XCTAssertEqual(back.x, 100, accuracy: 1e-9, "back where it began")
        XCTAssertGreaterThan(whole.count, 2, "drawn, not a point")

        let wedge = CanvasArithmetic.arc(in: room, start: 0, end: 90, clockwise: true, closed: false, wedge: true)
        XCTAssertEqual(Array(wedge.prefix(2)), [.move(Point(x: 50, y: 50)), .line(Point(x: 100, y: 50))])
        XCTAssertEqual(wedge.last, .close)
    }
}
