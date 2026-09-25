// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

import CStateUIWinUI
@_spi(Host) import StateUI
@testable import StateUIWinUI
import XCTest

/// A canvas that says where a press on it went, a switch that widens it, and one that takes it away.
private struct PressPage: ContentView {
    @State private var said = ""
    @State private var wide = false
    @State private var shown = true

    var content: any View {
        VStack {
            Label(said)
            if shown {
                Canvas {
                    Draw.fillColor(Color("#FF0000"))
                    Draw.fillRectangle(x: 0, y: 0, width: 300, height: 20)
                }
                .width(wide ? 200 : 100)
                .height(20)
                .horizontalAlignment(.start)
                .onPressed { point in said += "pressed \(Int(point.x)),\(Int(point.y)); " }
                .onDragged { point in said += "dragged \(Int(point.x)),\(Int(point.y)); " }
                .onReleased { point in said += "released \(Int(point.x)),\(Int(point.y)); " }
            }
            Button("Widen").onClicked { wide = true }
            Button("Hide").onClicked { shown = false }
        }
        .width(300)
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

/// A canvas a click shows.
private struct ShowingPage: ContentView {
    @State private var shown = false

    var content: any View {
        VStack {
            if shown {
                Canvas {
                    Draw.fillColor(Color("#FF0000"))
                    Draw.fillRectangle(x: 0, y: 0, width: 300, height: 20)
                }
                .width(100)
                .height(20)
            }
            Button("Show").onClicked { shown = true }
        }
        .horizontalAlignment(.start)
        .verticalAlignment(.start)
    }
}

final class WinUICanvasViewTests: XCTestCase {
    private static let red: UInt32 = 0xFFFF_0000
    private static let blue: UInt32 = 0xFF00_00FF

    /// The instructions run in order: a colour holds until the next, and a later shape paints over an earlier one.
    func testInstructionsRunInOrder() throws {
        let colours = try drawn(width: 100, height: 40, at: [(10, 20), (60, 20), (95, 20)]) {
            Draw.fillColor(Color("#FF0000"))
            Draw.fillRectangle(x: 0, y: 0, width: 80, height: 40)
            Draw.fillColor(Color("#0000FF"))
            Draw.fillRectangle(x: 50, y: 0, width: 20, height: 40)
        }
        XCTAssertEqual(colours, [Self.red, Self.blue, 0])
    }

    /// A transform moves what is drawn after it, and restoreState puts back what saveState kept: the colour and
    /// the transform alike.
    func testRestoreStatePutsBackTheColourAndTheTransform() throws {
        let colours = try drawn(width: 100, height: 20, at: [(5, 10), (45, 10), (85, 10), (25, 10)]) {
            Draw.fillColor(Color("#FF0000"))
            Draw.saveState()
            Draw.translate(dx: 40, dy: 0)
            Draw.fillColor(Color("#0000FF"))
            Draw.fillRectangle(x: 0, y: 0, width: 10, height: 20)
            Draw.restoreState()
            Draw.fillRectangle(x: 0, y: 0, width: 10, height: 20)
            Draw.fillRectangle(x: 80, y: 0, width: 10, height: 20)
        }
        XCTAssertEqual(colours, [Self.red, Self.blue, Self.red, 0])
    }

    /// A drawing reaching past the canvas is cut at its edge: nothing beside the canvas is painted.
    func testADrawingIsCutAtTheCanvasEdge() throws {
        let colours = try drawn(width: 40, height: 40, at: [(20, 20), (60, 20), (20, 60)]) {
            Draw.fillColor(Color("#FF0000"))
            Draw.fillRectangle(x: -50, y: -50, width: 200, height: 200)
        }
        XCTAssertEqual(colours, [Self.red, 0, 0])
    }

    /// A wedge is filled from the middle of its oval, from its start round to its end the way it turns.
    func testAWedgeTurnsTheWayItIsTold() throws {
        let clockwise = try drawn(width: 100, height: 100, at: [(75, 75), (25, 25), (75, 25), (25, 75)]) {
            Draw.fillColor(Color("#FF0000"))
            Draw.fillArc(x: 0, y: 0, width: 100, height: 100, startAngle: 0, endAngle: 90, clockwise: true)
        }
        XCTAssertEqual(clockwise, [Self.red, 0, 0, 0], "a quarter, down from the right")

        let counter = try drawn(width: 100, height: 100, at: [(25, 25), (75, 75), (75, 25), (25, 75)]) {
            Draw.fillColor(Color("#FF0000"))
            Draw.fillArc(x: 0, y: 0, width: 100, height: 100, startAngle: 0, endAngle: 90, clockwise: false)
        }
        XCTAssertEqual(counter, [Self.red, 0, Self.red, Self.red], "the three quarters up from the right")
    }

    /// A path is drawn from its own numbers, and an outline follows its edge without filling it.
    func testAPathIsFilledAndAnEllipseOutlined() throws {
        let path = try drawn(width: 40, height: 40, at: [(5, 5), (35, 35)]) {
            Draw.fillColor(Color("#FF0000"))
            Draw.fillPath("M 0 0 L 40 0 L 0 40 Z")
        }
        XCTAssertEqual(path, [Self.red, 0])

        let outline = try drawn(width: 40, height: 40, at: [(20, 1), (20, 20)]) {
            Draw.strokeColor(Color("#0000FF"))
            Draw.strokeWidth(4)
            Draw.drawEllipse(x: 0, y: 0, width: 40, height: 40)
        }
        XCTAssertEqual(outline, [Self.blue, 0])
    }

    /// Text is written inside its box, set to its end; what wraps past the box is cut.
    func testTextIsWrittenInItsBox() throws {
        let row = (0..<100).map { (Double($0), 10.0) }
        let set = try drawn(width: 100, height: 20, at: row) {
            Draw.textColor(Color("#000000"))
            Draw.fontSize(16)
            Draw.drawText("WW", x: 0, y: 0, width: 100, height: 20, horizontalAlignment: .end)
        }
        XCTAssertTrue(set[0..<50].allSatisfy { $0 == 0 }, "set to its end, the text leaves the start empty")
        XCTAssertTrue(set[50..<100].contains { $0 != 0 }, "and is written at the end")

        let lines = [10.0, 30.0].flatMap { y in (0..<40).map { (Double($0), y) } }
        let wrapped = try drawn(width: 40, height: 40, at: lines) {
            Draw.textColor(Color("#000000"))
            Draw.fontSize(16)
            Draw.drawText("WWW WWW WWW", x: 0, y: 0, width: 40, height: 20)
        }
        XCTAssertTrue(wrapped[0..<40].contains { $0 != 0 }, "the first line is written in its box")
        XCTAssertTrue(wrapped[40..<80].allSatisfy { $0 == 0 }, "the lines wrapped past the box are cut")
    }

    /// A canvas WinUI takes out and puts back before it has loaded - as a tabbed view holds its page again when
    /// the window takes its tabs - is drawn: the unloading WinUI tells after the loading stops nothing.
    func testACanvasPutBackBeforeItLoadsIsDrawn() throws {
        try onUIThread {
            let host = WinUIRenderer.running { ShowingPage() }
            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            _ = host.core.runJobs()
            let stack = try XCTUnwrap(host.views(WinUIStackView.self).first)
            let held = stack.heldViews()
            stack.setChildren([])
            stack.setChildren(held)

            let canvas = try XCTUnwrap(host.views(WinUICanvasView.self).first)
            host.settle { canvas.pixels(at: [(50, 10)]) == [Self.red] }
            XCTAssertEqual(canvas.pixels(at: [(50, 10)]), [Self.red])
        }
    }

    /// A press says where it went down, where it was dragged and where it was lifted, in the canvas's own points.
    func testAPressSaysWhereItWent() throws {
        try onUIThread {
            let host = WinUIRenderer.running { PressPage() }
            let canvas = try XCTUnwrap(host.views(WinUICanvasView.self).first)

            canvas.pressed(phase: 0, at: Point(x: 5, y: 6))
            canvas.pressed(phase: 1, at: Point(x: 7, y: 8))
            canvas.pressed(phase: 2, at: Point(x: 9, y: 10))
            let expected = "pressed 5,6; dragged 7,8; released 9,10; "
            host.settle { host.views(WinUILabelView.self).first?.text == expected }

            XCTAssertEqual(host.views(WinUILabelView.self).first?.text, expected)
        }
    }

    /// A canvas given more room draws again at its new size.
    func testACanvasDrawsAgainAtANewSize() throws {
        try onUIThread {
            let host = WinUIRenderer.running { PressPage() }
            let canvas = try XCTUnwrap(host.views(WinUICanvasView.self).first)
            host.settle { canvas.pixels(at: [(50, 10)]) == [Self.red] }
            XCTAssertEqual(canvas.pixels(at: [(50, 10), (150, 10)]), [Self.red, 0])

            try XCTUnwrap(host.views(WinUIButtonView.self).first).invoke()
            host.settle { canvas.pixels(at: [(150, 10)]) == [Self.red] }
            XCTAssertEqual(canvas.pixels(at: [(150, 10)]), [Self.red], "drawn again, wider")
        }
    }

    /// A canvas that leaves the tree is let go of, drawn and shown as it was.
    func testACanvasThatLeavesIsLetGoOf() throws {
        try onUIThread {
            let host = WinUIRenderer.running { PressPage() }
            host.settle { host.views(WinUICanvasView.self).first?.pixels(at: [(50, 10)]) == [Self.red] }
            let canvases = stateui_winui_canvases()

            try XCTUnwrap(host.views(WinUIButtonView.self).last).invoke()
            host.settle { stateui_winui_canvases() == canvases - 1 }

            XCTAssertEqual(stateui_winui_canvases(), canvases - 1, "the canvas outlived its element")
        }
    }

    /// The colours at `points` of a canvas `width` by `height` showing `drawing`, standing at the corner of a
    /// stack larger than it, once the drawing paints one of them.
    private func drawn(
        width: Double, height: Double, at points: [(Double, Double)],
        @DrawingBuilder _ drawing: @escaping @Sendable () -> [DrawCommand]
    ) throws -> [UInt32] {
        try onUIThread {
            let host = WinUIRenderer.running {
                VStack {
                    Canvas(drawing)
                        .width(width)
                        .height(height)
                        .horizontalAlignment(.start)
                }
                .width(width + 40)
                .height(height + 40)
                .horizontalAlignment(.start)
                .verticalAlignment(.start)
            }
            let stack = try XCTUnwrap(host.views(WinUIStackView.self).first)
            XCTAssertEqual(host.views(WinUICanvasView.self).count, 1, "one canvas")
            host.settle { stack.pixels(at: points).contains { $0 != 0 } }
            return stack.pixels(at: points)
        }
    }
}
