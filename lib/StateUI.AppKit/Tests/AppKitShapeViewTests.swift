// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@testable import StateUIAppKit
import XCTest

final class AppKitShapeViewTests: XCTestCase {
    @MainActor
    func testLineKeepsAuthoredPointsAndScalesItsDashUnitsByStrokeWidth() {
        let view = AppKitShapeView(kind: .line)
        view.frame = NSRect(x: 0, y: 0, width: 80, height: 40)
        view.apply(
            fill: nil,
            stroke: brush(.cornflowerBlue),
            thickness: 4,
            dash: [3, 2],
            dashOffset: 2.5,
            lineCap: PenLineCap.round.rawValue,
            lineJoin: PenLineJoin.miter.rawValue,
            miterLimit: 10,
            aspect: Stretch.none.rawValue,
            renderTransform: nil,
            geometry: .line(x1: 2, y1: 3, x2: 70, y2: 30))

        let path = view.pathForTesting(in: view.bounds)

        XCTAssertEqual(path.element(at: 0).points.first, NSPoint(x: 2, y: 3))
        XCTAssertEqual(path.element(at: 1).points.first, NSPoint(x: 70, y: 30))
        XCTAssertEqual(view.dashPatternForTesting, [12, 8])
        XCTAssertEqual(view.dashPhaseForTesting, 10)
        XCTAssertEqual(path.lineCapStyle, .round)
    }

    @MainActor
    func testPolygonClosesItsNativePathAndUsesTheRequestedWindingRule() {
        let view = AppKitShapeView(kind: .polygon)
        view.apply(
            fill: brush(.red),
            stroke: nil,
            thickness: 1,
            dash: [],
            dashOffset: 0,
            lineCap: 0,
            lineJoin: 0,
            miterLimit: 10,
            aspect: Stretch.none.rawValue,
            renderTransform: nil,
            geometry: .points([0, 0, 40, 0, 20, 30], fillRule: FillRule.evenOdd.rawValue))

        let path = view.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 30))

        XCTAssertTrue((0..<path.elementCount).contains {
            path.element(at: $0).type == .closePath
        })
        XCTAssertEqual(path.windingRule, .evenOdd)
    }

    @MainActor
    func testUniformStretchCentersGeometryWithoutChangingItsProportions() {
        let view = AppKitShapeView(kind: .polyline)
        view.apply(
            fill: nil,
            stroke: brush(.black),
            thickness: 1,
            dash: [],
            dashOffset: 0,
            lineCap: 0,
            lineJoin: 0,
            miterLimit: 10,
            aspect: Stretch.uniform.rawValue,
            renderTransform: nil,
            geometry: .points([0, 0, 100, 50], fillRule: FillRule.nonzero.rawValue))

        let bounds = view.pathForTesting(in: NSRect(x: 0, y: 0, width: 200, height: 200))
            .bounds

        XCTAssertEqual(bounds, NSRect(x: 0, y: 50, width: 200, height: 100))
    }

    @MainActor
    func testSVGPathUsesTheSharedParserForLinesCurvesAndClosure() {
        let view = AppKitShapeView(kind: .path)
        view.apply(
            fill: brush(.gold),
            stroke: nil,
            thickness: 1,
            dash: [],
            dashOffset: 0,
            lineCap: 0,
            lineJoin: 0,
            miterLimit: 10,
            aspect: Stretch.none.rawValue,
            renderTransform: nil,
            geometry: .path("M 0 40 L 20 0 C 25 5 35 5 40 40 Z"))

        let path = view.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 40))
        let types = (0..<path.elementCount).map { path.element(at: $0).type }

        XCTAssertEqual(path.bounds, NSRect(x: 0, y: 0, width: 40, height: 40))
        XCTAssertTrue(types.contains(.cubicCurveTo))
        XCTAssertTrue(types.contains(.closePath))
    }

    @MainActor
    func testSVGArcEndsAtItsAuthoredPoint() {
        let view = AppKitShapeView(kind: .path)
        view.apply(
            fill: nil,
            stroke: brush(.black),
            thickness: 1,
            dash: [],
            dashOffset: 0,
            lineCap: 0,
            lineJoin: 0,
            miterLimit: 10,
            aspect: Stretch.none.rawValue,
            renderTransform: nil,
            geometry: .path("M 0 20 A 20 20 0 0 1 40 20"))

        let path = view.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 40))
        let curves = (0..<path.elementCount)
            .map { path.element(at: $0) }
            .filter { $0.type == .cubicCurveTo }

        XCTAssertFalse(curves.isEmpty)
        XCTAssertEqual(curves.last?.points.last?.x ?? -1, 40, accuracy: 0.000_001)
        XCTAssertEqual(curves.last?.points.last?.y ?? -1, 20, accuracy: 0.000_001)
    }

    @MainActor
    func testHostPatchMapsShapeGeometryAndStrokeProperties() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var line = HostPatch(id: .manual("line"), type: .line)
        line.properties[.x1] = .number(1)
        line.properties[.y1] = .number(2)
        line.properties[.x2] = .number(41)
        line.properties[.y2] = .number(22)
        line.properties[.strokeThickness] = .number(3)
        line.properties[.strokeDashArray] = .numbers([2, 1])
        line.properties[.aspect] = .enumeration(Stretch.none.rawValue)
        renderer.applyForTesting(tree(line))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("line")) as? AppKitShapeView)
        let path = native.pathForTesting(in: NSRect(x: 0, y: 0, width: 50, height: 30))

        XCTAssertEqual(path.element(at: 0).points.first, NSPoint(x: 1, y: 2))
        XCTAssertEqual(path.element(at: 1).points.first, NSPoint(x: 41, y: 22))
        XCTAssertEqual(native.dashPatternForTesting, [6, 3])
    }

    @MainActor
    func testHostPatchMapsTheStructuredShapeRenderTransform() throws {
        let renderer = AppKitRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var line = HostPatch(id: .manual("line"), type: .line)
        line.properties[.x1] = .number(1)
        line.properties[.y1] = .number(2)
        line.properties[.x2] = .number(21)
        line.properties[.y2] = .number(12)
        line.properties[.aspect] = .enumeration(Stretch.none.rawValue)
        line.properties[.renderTransform] = .values([
            .number(1), .number(0), .number(0),
            .number(1), .number(10), .number(20),
        ])
        renderer.applyForTesting(tree(line))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("line")) as? AppKitShapeView)
        let path = native.pathForTesting(in: NSRect(x: 0, y: 0, width: 50, height: 30))

        XCTAssertEqual(path.element(at: 0).points.first, NSPoint(x: 11, y: 22))
        XCTAssertEqual(path.element(at: 1).points.first, NSPoint(x: 31, y: 32))
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

    private func brush(_ color: Color) -> HostValue {
        Brush.solidColor(color).propValue
    }
}

private extension NSBezierPath {
    func element(at index: Int) -> (type: NSBezierPath.ElementType, points: [NSPoint]) {
        var points = Array(repeating: NSPoint.zero, count: 3)
        let type = element(at: index, associatedPoints: &points)
        let count: Int
        switch type {
        case .moveTo, .lineTo: count = 1
        case .cubicCurveTo: count = 3
        case .quadraticCurveTo: count = 2
        case .closePath: count = 0
        @unknown default: count = 0
        }
        return (type, Array(points.prefix(count)))
    }
}

#endif
