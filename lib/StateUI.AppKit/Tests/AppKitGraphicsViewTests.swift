// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitGraphicsViewTests: XCTestCase {
    @MainActor
    func testEveryDrawingCommandDecodesInAuthoredOrder() throws {
        let element = GraphicsView {
            Draw.fillColor(.red)
            Draw.strokeColor(.blue)
            Draw.fontColor(.white)
            Draw.strokeSize(2)
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
            Draw.drawString("text", x: 0, y: 0, width: 20, height: 10)
            Draw.translate(dx: 2, dy: 3)
            Draw.rotate(30)
            Draw.scale(sx: 2, sy: 2)
            Draw.saveState()
            Draw.restoreState()
        }
        let value = try XCTUnwrap(element.node.props[.drawable])
        let view = AppKitGraphicsView()

        view.apply(value)

        XCTAssertEqual(view.commandKindsForTesting, Array(0...22).map(Int32.init))
    }

    @MainActor
    func testFillCommandsRenderIntoTheNativeBitmap() throws {
        let element = GraphicsView {
            Draw.fillColor(.red)
            Draw.fillRectangle(x: 10, y: 10, width: 20, height: 20)
        }
        let view = AppKitGraphicsView()
        view.frame = NSRect(x: 0, y: 0, width: 40, height: 40)
        view.apply(try XCTUnwrap(element.node.props[.drawable]))

        let image = try bitmap(of: view)

        XCTAssertGreaterThan(image.colorAt(x: 15, y: 15)?.redComponent ?? 0, 0.9)
        XCTAssertEqual(image.colorAt(x: 2, y: 2)?.alphaComponent ?? 0, 0, accuracy: 0.01)
    }

    @MainActor
    func testPointerPhasesReportCanvasCoordinatesExactlyOnce() {
        let view = AppKitGraphicsView()
        var reports: [(Int, NSPoint)] = []
        view.onStartInteraction = { reports.append((0, $0)) }
        view.onDragInteraction = { reports.append((1, $0)) }
        view.onEndInteraction = { reports.append((2, $0)) }

        view.startInteractionForTesting(at: NSPoint(x: 2, y: 3))
        view.dragInteractionForTesting(at: NSPoint(x: 5, y: 7))
        view.endInteractionForTesting(at: NSPoint(x: 11, y: 13))

        XCTAssertEqual(reports.map(\.0), [0, 1, 2])
        XCTAssertEqual(reports.map(\.1), [
            NSPoint(x: 2, y: 3), NSPoint(x: 5, y: 7), NSPoint(x: 11, y: 13),
        ])
    }

    @MainActor
    func testHostPatchMapsDrawingAndInteractionEvents() throws {
        var reports: [(Int32, [HostValue])] = []
        let renderer = AppKitRenderer(
            resourceDirectory: nil,
            presentsWindows: false,
            eventSink: { reports.append(($0, $1)) })
        defer { renderer.closeForTesting() }
        let element = GraphicsView {
            Draw.fillColor(.blue)
            Draw.fillEllipse(x: 0, y: 0, width: 20, height: 20)
        }
        var canvas = HostPatch(id: .manual("canvas"), type: .graphicsView)
        canvas.properties[.drawable] = try XCTUnwrap(element.node.props[.drawable])
        canvas.events = .replace([
            .startInteraction: 10,
            .dragInteraction: 11,
            .endInteraction: 12,
        ])

        renderer.applyForTesting(tree(canvas))
        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("canvas")) as? AppKitGraphicsView)
        native.startInteractionForTesting(at: NSPoint(x: 3, y: 4))
        native.dragInteractionForTesting(at: NSPoint(x: 5, y: 6))
        native.endInteractionForTesting(at: NSPoint(x: 7, y: 8))

        XCTAssertEqual(native.commandKindsForTesting, [0, 14])
        XCTAssertEqual(reports.map(\.0), [10, 11, 12])
        XCTAssertEqual(reports.map(\.1), [
            [.numbers([3, 4])], [.numbers([5, 6])], [.numbers([7, 8])],
        ])
    }

    private func tree(_ content: HostPatch) -> HostPatch {
        var page = HostPatch(id: .manual("page"), type: .contentPage)
        page.children = .arranged([content])
        var window = HostPatch(id: .manual("window"), type: .window)
        window.children = .arranged([page])
        var scene = HostPatch(id: .manual("scene"), type: .scene)
        scene.children = .arranged([window])
        var application = HostPatch(id: .manual("application"), type: .application)
        application.children = .arranged([scene])
        return application
    }

    @MainActor
    private func bitmap(of view: NSView) throws -> NSBitmapImageRep {
        let image = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: Int(view.bounds.width),
            pixelsHigh: Int(view.bounds.height),
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bytesPerRow: 0,
            bitsPerPixel: 0)
        let bitmap = try XCTUnwrap(image)
        let context = try XCTUnwrap(NSGraphicsContext(bitmapImageRep: bitmap))
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        view.draw(view.bounds)
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()
        return bitmap
    }
}

#endif
