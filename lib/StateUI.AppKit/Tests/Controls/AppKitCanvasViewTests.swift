// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitCanvasViewTests: XCTestCase {
    @MainActor
    func testEveryDrawingCommandDecodesInAuthoredOrder() throws {
        let element = Canvas {
            Draw.fillColor(.red)
            Draw.strokeColor(.blue)
            Draw.textColor(.white)
            Draw.strokeWidth(2)
            Draw.fontSize(14)
            Draw.alpha(0.8)
            Draw.drawLine(x1: 0, y1: 0, x2: 10, y2: 10)
            Draw.drawRectangle(x: 0, y: 0, width: 10, height: 10)
            Draw.drawRoundedRectangle(x: 0, y: 0, width: 10, height: 10, cornerRadius: 2)
            Draw.drawEllipse(x: 0, y: 0, width: 10, height: 10)
            Draw.drawArc(
                x: 0, y: 0, width: 10, height: 10,
                startAngle: 0, endAngle: 90, clockwise: true, closed: false)
            Draw.drawPath("M0 0 L10 10")
            Draw.fillRectangle(x: 0, y: 0, width: 10, height: 10)
            Draw.fillRoundedRectangle(x: 0, y: 0, width: 10, height: 10, cornerRadius: 2)
            Draw.fillEllipse(x: 0, y: 0, width: 10, height: 10)
            Draw.fillArc(
                x: 0, y: 0, width: 10, height: 10,
                startAngle: 0, endAngle: 90, clockwise: true)
            Draw.fillPath("M0 0 L10 0 L10 10 Z")
            Draw.drawText("text", x: 0, y: 0, width: 20, height: 10)
            Draw.translate(dx: 2, dy: 3)
            Draw.rotate(30)
            Draw.scale(sx: 2, sy: 2)
            Draw.saveState()
            Draw.restoreState()
        }
        let value = try XCTUnwrap(element.node.props[.drawable])
        let view = AppKitCanvasView()

        view.apply(value)

        XCTAssertEqual(view.commandKindsForTesting, Array(0...22).map(Int32.init))
    }

    @MainActor
    func testFillCommandsRenderIntoTheNativeBitmap() throws {
        let element = Canvas {
            Draw.fillColor(.red)
            Draw.fillRectangle(x: 10, y: 10, width: 20, height: 20)
        }
        let view = AppKitCanvasView()
        view.frame = NSRect(x: 0, y: 0, width: 40, height: 40)
        view.apply(try XCTUnwrap(element.node.props[.drawable]))

        let image = try bitmap(of: view)

        XCTAssertGreaterThan(image.colorAt(x: 15, y: 15)?.redComponent ?? 0, 0.9)
        XCTAssertEqual(image.colorAt(x: 2, y: 2)?.alphaComponent ?? 0, 0, accuracy: 0.01)
    }

    /// A canvas draws inside its own frame, as a canvas does on every other
    /// platform: an instruction that reaches past the edge is cut there, not
    /// painted over whatever stands beside the canvas.
    @MainActor
    func testADrawingIsCutAtTheCanvasEdge() throws {
        let element = Canvas {
            Draw.fillColor(.red)
            Draw.fillRectangle(x: 0, y: 0, width: 80, height: 20)
        }
        let view = AppKitCanvasView()
        view.frame = NSRect(x: 0, y: 0, width: 20, height: 20)
        view.apply(try XCTUnwrap(element.node.props[.drawable]))

        let image = try bitmap(of: view, width: 80)

        XCTAssertGreaterThan(image.colorAt(x: 10, y: 10)?.redComponent ?? 0, 0.9, "inside")
        XCTAssertEqual(
            image.colorAt(x: 50, y: 10)?.alphaComponent ?? 1, 0, accuracy: 0.01, "past the edge")
    }

    @MainActor
    func testPointerPhasesReportCanvasCoordinatesExactlyOnce() {
        let view = AppKitCanvasView()
        var reports: [(Int, NSPoint)] = []
        view.onPressed = { reports.append((0, $0)) }
        view.onDragged = { reports.append((1, $0)) }
        view.onReleased = { reports.append((2, $0)) }

        view.pressForTesting(at: NSPoint(x: 2, y: 3))
        view.dragForTesting(at: NSPoint(x: 5, y: 7))
        view.releaseForTesting(at: NSPoint(x: 11, y: 13))

        XCTAssertEqual(reports.map(\.0), [0, 1, 2])
        XCTAssertEqual(reports.map(\.1), [
            NSPoint(x: 2, y: 3), NSPoint(x: 5, y: 7), NSPoint(x: 11, y: 13),
        ])
    }

    @MainActor
    func testHostPatchMapsDrawingAndInteractionEvents() throws {
        var reports: [(Int32, [HostValue])] = []
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }
        let element = Canvas {
            Draw.fillColor(.blue)
            Draw.fillEllipse(x: 0, y: 0, width: 20, height: 20)
        }
        var canvas = HostPatch(id: .manual("canvas"), type: .canvas)
        canvas.properties[.drawable] = try XCTUnwrap(element.node.props[.drawable])
        canvas.events = .replace([
            .pressed: 10,
            .dragged: 11,
            .released: 12,
        ])

        renderer.applyForTesting(tree(canvas))
        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("canvas")) as? AppKitCanvasView)
        native.pressForTesting(at: NSPoint(x: 3, y: 4))
        native.dragForTesting(at: NSPoint(x: 5, y: 6))
        native.releaseForTesting(at: NSPoint(x: 7, y: 8))

        XCTAssertEqual(native.commandKindsForTesting, [0, 14])
        XCTAssertEqual(reports.map(\.0), [10, 11, 12])
        XCTAssertEqual(reports.map(\.1), [
            [.numbers([3, 4])], [.numbers([5, 6])], [.numbers([7, 8])],
        ])
    }
}

#endif
