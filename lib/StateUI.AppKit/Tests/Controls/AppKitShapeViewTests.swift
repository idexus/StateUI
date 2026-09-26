// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) @testable import StateUI
@_spi(Host) @testable import StateUIHost
@testable import StateUIAppKit
import XCTest

final class AppKitShapeViewTests: XCTestCase {
    @MainActor
    func testLineKeepsAuthoredPointsAndScalesItsDashUnitsByStrokeWidth() {
        let view = AppKitShapeView(kind: .line)
        view.frame = NSRect(x: 0, y: 0, width: 72, height: 33)
        view.apply(
            fill: nil,
            stroke: brush(.cornflowerBlue),
            strokeWidth: 4,
            dash: [3, 2],
            dashOffset: 2.5,
            lineCap: LineCap.round.rawValue,
            lineJoin: LineJoin.miter.rawValue,
            miterLimit: 10,
            aspect: Aspect.center.rawValue,
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
            strokeWidth: 1,
            dash: [],
            dashOffset: 0,
            lineCap: 0,
            lineJoin: 0,
            miterLimit: 10,
            aspect: Aspect.center.rawValue,
            renderTransform: nil,
            geometry: .points([0, 0, 40, 0, 20, 30], fillRule: FillRule.evenOdd.rawValue))

        let path = view.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 30))

        XCTAssertTrue((0..<path.elementCount).contains {
            path.element(at: $0).type == .closePath
        })
        XCTAssertEqual(path.windingRule, .evenOdd)
    }

    @MainActor
    func testAFittedShapeIsCentredWithoutChangingItsProportions() {
        let view = AppKitShapeView(kind: .polyline)
        view.apply(
            fill: nil,
            stroke: brush(.black),
            strokeWidth: 1,
            dash: [],
            dashOffset: 0,
            lineCap: 0,
            lineJoin: 0,
            miterLimit: 10,
            aspect: Aspect.fit.rawValue,
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
            strokeWidth: 1,
            dash: [],
            dashOffset: 0,
            lineCap: 0,
            lineJoin: 0,
            miterLimit: 10,
            aspect: Aspect.center.rawValue,
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
            strokeWidth: 1,
            dash: [],
            dashOffset: 0,
            lineCap: 0,
            lineJoin: 0,
            miterLimit: 10,
            aspect: Aspect.center.rawValue,
            renderTransform: nil,
            geometry: .path("M 0 20 A 20 20 0 0 1 40 20"))

        let path = view.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 20))
        let curves = (0..<path.elementCount)
            .map { path.element(at: $0) }
            .filter { $0.type == .cubicCurveTo }

        XCTAssertFalse(curves.isEmpty)
        XCTAssertEqual(curves.last?.points.last?.x ?? -1, 40, accuracy: 0.000_001)
        XCTAssertEqual(curves.last?.points.last?.y ?? -1, 20, accuracy: 0.000_001)
    }

    @MainActor
    func testHostPatchMapsShapeGeometryAndStrokeProperties() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var line = HostPatch(id: .manual("line"), type: .line)
        line.properties[.x1] = .number(1)
        line.properties[.y1] = .number(2)
        line.properties[.x2] = .number(41)
        line.properties[.y2] = .number(22)
        line.properties[.strokeWidth] = .number(3)
        line.properties[.strokeDashPattern] = .numbers([2, 1])
        line.properties[.aspect] = .enumeration(Aspect.center.rawValue)
        renderer.applyForTesting(tree(line))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("line")) as? AppKitShapeView)
        let path = native.pathForTesting(in: NSRect(x: 0, y: 0, width: 42, height: 24))

        XCTAssertEqual(path.element(at: 0).points.first, NSPoint(x: 1, y: 2))
        XCTAssertEqual(path.element(at: 1).points.first, NSPoint(x: 41, y: 22))
        XCTAssertEqual(native.dashPatternForTesting, [6, 3])
    }

    @MainActor
    func testHostPatchMapsTheStructuredShapeRenderTransform() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }

        var line = HostPatch(id: .manual("line"), type: .line)
        line.properties[.x1] = .number(1)
        line.properties[.y1] = .number(2)
        line.properties[.x2] = .number(21)
        line.properties[.y2] = .number(12)
        line.properties[.aspect] = .enumeration(Aspect.center.rawValue)
        line.properties[.renderTransform] = .values([
            .number(1), .number(0), .number(0),
            .number(1), .number(10), .number(20),
        ])
        renderer.applyForTesting(tree(line))

        let native = try XCTUnwrap(
            renderer.viewForTesting(id: .manual("line")) as? AppKitShapeView)
        let path = native.pathForTesting(in: NSRect(x: 0, y: 0, width: 22, height: 14))

        XCTAssertEqual(path.element(at: 0).points.first, NSPoint(x: 11, y: 22))
        XCTAssertEqual(path.element(at: 1).points.first, NSPoint(x: 31, y: 32))
    }

    /// Every shape strokes as its properties say: the stroke's width, its dash
    /// and the dash's offset, both in units of that width, its caps, its joins
    /// and its miter limit.
    @MainActor
    func testHostPatchStrokesEveryShapeAsItsPropertiesSay() throws {
        for (type, geometry) in Self.shapes {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var shape = HostPatch(id: .manual("shape"), type: type)
            shape.properties = geometry.merging([
                .strokeWidth: .number(2),
                .strokeDashPattern: .numbers([3, 1]),
                .strokeDashOffset: .number(0.5),
                .strokeLineCap: .enumeration(LineCap.square.rawValue),
                .strokeLineJoin: .enumeration(LineJoin.round.rawValue),
                .strokeMiterLimit: .number(4),
            ]) { $1 }
            renderer.applyForTesting(tree(shape))

            let native = try XCTUnwrap(
                renderer.viewForTesting(id: .manual("shape")) as? AppKitShapeView, type.name)
            let path = native.pathForTesting(in: NSRect(x: 0, y: 0, width: 40, height: 20))
            XCTAssertEqual(path.lineWidth, 2, type.name)
            XCTAssertEqual(path.lineCapStyle, .square, type.name)
            XCTAssertEqual(path.lineJoinStyle, .round, type.name)
            XCTAssertEqual(path.miterLimit, 4, type.name)
            XCTAssertEqual(native.dashPatternForTesting, [6, 2], type.name)
            XCTAssertEqual(native.dashPhaseForTesting, 1, type.name)
        }
    }

    /// Every shape draws its fill inside its outline and its stroke along it,
    /// each in its brush's colour. A line holds no area to fill.
    @MainActor
    func testEveryShapeDrawsItsFillAndItsStroke() throws {
        for (type, geometry) in Self.shapes {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var shape = HostPatch(id: .manual("shape"), type: type)
            shape.properties = geometry.merging([
                .fill: brush(.red),
                .stroke: brush(.blue),
                .strokeWidth: .number(4),
            ]) { $1 }
            renderer.applyForTesting(tree(shape))

            let native = try XCTUnwrap(renderer.viewForTesting(id: .manual("shape")), type.name)
            native.frame = NSRect(x: 0, y: 0, width: 40, height: 20)
            let drawn = try bitmap(of: native)
            let filled = pixels(in: drawn) { $0.redComponent > 0.8 && $0.blueComponent < 0.3 }
            let stroked = pixels(in: drawn) { $0.blueComponent > 0.8 && $0.redComponent < 0.3 }
            XCTAssertGreaterThan(stroked, 0, type.name)
            if type == .line {
                XCTAssertEqual(filled, 0, type.name)
            } else {
                XCTAssertGreaterThan(filled, 0, type.name)
            }
        }
    }

    /// A line, a path, a polygon and a polyline are drawn from their own
    /// numbers: the aspect places that drawing in the room, the render
    /// transform then moves what was drawn, and a fill rule reaches the
    /// outline it applies to.
    @MainActor
    func testHostPatchPlacesAndMovesEveryAuthoredGeometry() throws {
        let authored: [(NodeType, [Prop: HostValue])] = [
            (.line, [.x1: .number(0), .y1: .number(0), .x2: .number(100), .y2: .number(50)]),
            (.path, [.data: .string("M 0 0 L 100 50")]),
            (.polygon, [
                .points: .numbers([0, 0, 100, 0, 100, 50]),
                .fillRule: .enumeration(FillRule.nonzero.rawValue),
            ]),
            (.polyline, [
                .points: .numbers([0, 0, 100, 50]),
                .fillRule: .enumeration(FillRule.nonzero.rawValue),
            ]),
        ]
        let room = NSRect(x: 0, y: 0, width: 200, height: 200)

        for (type, geometry) in authored {
            let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
            defer { renderer.closeForTesting() }
            var fitted = HostPatch(id: .manual("fitted"), type: type)
            fitted.properties = geometry.merging([.aspect: .enumeration(Aspect.fit.rawValue)]) { $1 }
            var moved = HostPatch(id: .manual("moved"), type: type)
            moved.properties = geometry.merging([
                .aspect: .enumeration(Aspect.stretch.rawValue),
                .renderTransform: .values([
                    .number(1), .number(0), .number(0),
                    .number(1), .number(10), .number(20),
                ]),
            ]) { $1 }
            var stack = HostPatch(id: .manual("stack"), type: .vStack)
            stack.children = .arranged([fitted, moved])
            renderer.applyForTesting(tree(stack))

            let nativeFitted = try XCTUnwrap(
                renderer.viewForTesting(id: .manual("fitted")) as? AppKitShapeView, type.name)
            let nativeMoved = try XCTUnwrap(
                renderer.viewForTesting(id: .manual("moved")) as? AppKitShapeView, type.name)
            let fittedPath = nativeFitted.pathForTesting(in: room)
            XCTAssertEqual(fittedPath.bounds, NSRect(x: 0, y: 50, width: 200, height: 100), type.name)
            XCTAssertEqual(
                nativeMoved.pathForTesting(in: room).bounds,
                NSRect(x: 10, y: 20, width: 200, height: 200),
                type.name)
            if type == .polygon || type == .polyline {
                XCTAssertEqual(fittedPath.windingRule, .nonZero, type.name)
            }
        }
    }

    /// A rectangle's corner radius rounds its outline; without one its
    /// corners stay square.
    @MainActor
    func testARectanglesCornerRadiusRoundsItsOutline() throws {
        let renderer = testRenderer(resourceDirectory: nil, presentsWindows: false)
        defer { renderer.closeForTesting() }
        var rounded = HostPatch(id: .manual("rounded"), type: .rectangle)
        rounded.properties[.cornerRadius] = .number(8)
        let square = HostPatch(id: .manual("square"), type: .rectangle)
        var stack = HostPatch(id: .manual("stack"), type: .vStack)
        stack.children = .arranged([rounded, square])
        renderer.applyForTesting(tree(stack))

        func curves(_ id: String) throws -> Int {
            let native = try XCTUnwrap(
                renderer.viewForTesting(id: .manual(id)) as? AppKitShapeView, id)
            let path = native.pathForTesting(in: NSRect(x: 0, y: 0, width: 60, height: 40))
            return (0..<path.elementCount).filter { path.element(at: $0).type == .cubicCurveTo }.count
        }
        XCTAssertGreaterThan(try curves("rounded"), 0)
        XCTAssertEqual(try curves("square"), 0)
    }

    /// One of each shape, with a geometry filling a room of 40 by 20.
    private static let shapes: [(NodeType, [Prop: HostValue])] = [
        (.rectangle, [:]),
        (.ellipse, [:]),
        (.line, [.x1: .number(0), .y1: .number(10), .x2: .number(40), .y2: .number(10)]),
        (.path, [.data: .string("M 0 0 L 40 0 L 40 20 L 0 20 Z")]),
        (.polygon, [.points: .numbers([0, 0, 40, 0, 40, 20, 0, 20])]),
        (.polyline, [.points: .numbers([0, 0, 40, 0, 40, 20, 0, 20])]),
    ]

    /// How many pixels of `bitmap` are ones `matches` accepts, among those
    /// drawn at all.
    private func pixels(in bitmap: NSBitmapImageRep, where matches: (NSColor) -> Bool) -> Int {
        var count = 0
        for x in 0..<bitmap.pixelsWide {
            for y in 0..<bitmap.pixelsHigh {
                if let colour = bitmap.colorAt(x: x, y: y), colour.alphaComponent > 0.8, matches(colour) {
                    count += 1
                }
            }
        }
        return count
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
