// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

@MainActor
final class AppKitCanvasViewTests: XCTestCase {
    @MainActor
    func testEveryDrawingCommandDecodesInAuthoredOrder() throws {
        let element = Canvas {
            Draw.fillColor(.red)
            Draw.strokeColor(.blue)
            Draw.textColor(.white)
            Draw.lineWidth(2)
            Draw.fontSize(14)
            Draw.opacity(0.8)
            Draw.strokeLine(x1: 0, y1: 0, x2: 10, y2: 10)
            Draw.strokeRectangle(x: 0, y: 0, width: 10, height: 10)
            Draw.strokeRoundedRectangle(x: 0, y: 0, width: 10, height: 10, cornerRadius: 2)
            Draw.strokeEllipse(x: 0, y: 0, width: 10, height: 10)
            Draw.strokeArc(
                x: 0, y: 0, width: 10, height: 10,
                startAngle: 0, endAngle: 90, clockwise: true, closed: false)
            Draw.strokePath("M0 0 L10 10")
            Draw.fillRectangle(x: 0, y: 0, width: 10, height: 10)
            Draw.fillRoundedRectangle(x: 0, y: 0, width: 10, height: 10, cornerRadius: 2)
            Draw.fillEllipse(x: 0, y: 0, width: 10, height: 10)
            Draw.fillArc(
                x: 0, y: 0, width: 10, height: 10,
                startAngle: 0, endAngle: 90, clockwise: true)
            Draw.fillPath("M0 0 L10 0 L10 10 Z")
            Draw.text("text", x: 0, y: 0, width: 20, height: 10)
            Draw.translate(2, 3)
            Draw.rotate(30)
            Draw.scale(2)
            Draw.saveGraphics()
            Draw.restoreGraphics()
        }
        let value = try XCTUnwrap(element.node.props[.drawing])
        let view = AppKitCanvasView()

        view.apply(Self.drawing(value))

        XCTAssertEqual(view.instructionsForTesting.count, 23, "every kind read")
        XCTAssertEqual(view.instructionsForTesting.last, .restoreGraphics)
    }

    @MainActor
    func testFillCommandsRenderIntoTheNativeBitmap() throws {
        let element = Canvas {
            Draw.fillColor(.red)
            Draw.fillRectangle(x: 10, y: 10, width: 20, height: 20)
        }
        let view = AppKitCanvasView()
        view.frame = NSRect(x: 0, y: 0, width: 40, height: 40)
        view.apply(Self.drawing(try XCTUnwrap(element.node.props[.drawing])))

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
        view.apply(Self.drawing(try XCTUnwrap(element.node.props[.drawing])))

        let image = try bitmap(of: view, width: 80)

        XCTAssertGreaterThan(image.colorAt(x: 10, y: 10)?.redComponent ?? 0, 0.9, "inside")
        XCTAssertEqual(
            image.colorAt(x: 50, y: 10)?.alphaComponent ?? 1, 0, accuracy: 0.01, "past the edge")
    }

    @MainActor
    func testHostPatchMapsTheDrawing() throws {
        let renderer = testRenderer(
            resourceDirectory: nil,
            presentsWindows: false)
        defer { renderer.finish() }
        let element = Canvas {
            Draw.fillColor(.blue)
            Draw.fillEllipse(x: 0, y: 0, width: 20, height: 20)
        }
        var canvas = HostPatch(id: .manual("canvas"), type: .canvas)
        canvas.properties[.drawing] = try XCTUnwrap(element.node.props[.drawing])

        renderer.applyForTesting(tree(canvas))
        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("canvas")) as? AppKitCanvasView)
        XCTAssertEqual(native.instructionsForTesting.count, 2)
        XCTAssertEqual(native.instructionsForTesting.last, .fillEllipse(Rect(x: 0, y: 0, width: 20, height: 20)))
    }

    /// A drawing as the tree holds it, as its contract declares it.
    private static func drawing(_ value: HostValue) -> [DrawCommand] {
        value.values?.compactMap(DrawCommand.init(propValue:)) ?? []
    }
}

#endif
