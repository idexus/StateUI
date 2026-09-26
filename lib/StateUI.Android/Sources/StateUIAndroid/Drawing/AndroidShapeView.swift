// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIAndroid

/// A Rectangle, an Ellipse, a Line, a Path, a Polygon or a Polyline: the host's `StateUIShapeView`, told its
/// geometry, brush and outline one call each, and moved as the host layer places it (`ShapeArithmetic`) - a
/// rectangle and an ellipse by the shape's transform, drawn geometry by its aspect, then the transform.
/// Design: docs/design/platforms/android/drawing.md#shapes
@MainActor
final class AndroidShapeView: AndroidView {
    /// What a shape is drawn from.
    enum Geometry {
        /// The view's bounds, its corners' radii in points: top left, top right, bottom left, bottom right.
        case rectangle(CornerRadius?)
        case ellipse
        /// Authored geometry in points, closed where it is a polygon's.
        case line(Point, Point)
        case points([Point], closed: Bool, evenOdd: Bool)
        case path(String)
    }

    init() {
        super.init { _ in Java.new(JavaAPI.shapeView, JavaAPI.newShapeView, .object(AndroidRenderer.context)) }
    }

    /// Whether the shape draws geometry of its own, which its aspect places.
    private var drawsGeometry = false
    private var aspect = Aspect.fit
    private var transform: [Double]?

    /// Where the drawn geometry stands before it is placed, in points, as Android measures it.
    private var geometryBounds = Rect(x: 0, y: 0, width: 0, height: 0)

    /// The six numbers the shape was last moved by, in pixels; none before it was.
    private var placing: [Float]?

    /// A rectangle's corners' radii in points, clockwise from the top left; the outline's width in pixels; and the
    /// radii last told the Java side, fitted to the room.
    private var corners: [Double] = []
    private var strokePixels = 0.0
    private var toldCorners: [Float]?

    /// Everything the shape draws, from what the tree says.
    func draw(
        _ geometry: Geometry, fill: HostValue?, stroke: HostValue?, strokeWidth: Double, dashes: [Double],
        dashOffset: Double, cap: Int32, join: Int32, miterLimit: Double, aspect: Int32, transform: [Double]?
    ) {
        let (kind, commands, evenOdd) = Self.flattened(geometry, density: density)
        if case .rectangle(let radius) = geometry { corners = BoxArithmetic.clockwise(radius) } else { corners = [] }
        // Dashes are counted in the outline's own width, as StateUI's are.
        let width = ShapeArithmetic.strokeWidth(strokeWidth)
        let argb = HostBrush(stroke).firstColor.flatMap(AndroidView.argb)
        strokePixels = argb == nil ? 0 : width * density
        Java.frame {
            Java.call(
                reference, JavaAPI.setShapeGeometry, .int(kind), .object(Java.floats(commands)), .bool(evenOdd))

            let brush = AndroidShapeDrawable.brush(fill)
            Java.call(
                reference, JavaAPI.setShapeFill, .int(brush.kind), .object(Java.ints(brush.colors)),
                .object(Java.floats(brush.offsets)), .object(Java.floats(brush.geometry)))

            let dashes = ShapeArithmetic.dashLengths(dashes, strokeWidth: width).map { Float($0 * density) }
            Java.call(
                reference, JavaAPI.setShapeStroke, .int(argb ?? 0), .float(Float(strokePixels)),
                .object(Java.floats(dashes)), .float(Float(dashOffset * width * density)), .int(cap), .int(join),
                .float(Float(max(0, miterLimit))))
        }
        fitCorners()
        drawsGeometry = kind == 2
        self.aspect = Aspect(rawValue: aspect) ?? .fit
        self.transform = transform
        if drawsGeometry { geometryBounds = readGeometryBounds() }
        place()
    }

    override func layout(_ place: Rect) {
        super.layout(place)
        self.place()
    }

    override func sized(width: Int32, height: Int32) {
        fitCorners()
    }

    /// Tells the Java side a rectangle's corners, each no more than half the side it rounds within the outline
    /// (`BoxArithmetic`); unfitted before the shape is placed.
    private func fitCorners() {
        let room = placedSize.map { (Double($0.width) - strokePixels, Double($0.height) - strokePixels) }
        let fitted = corners.flatMap { radius -> [Float] in
            let pixels = radius * density
            guard let room else { return [Float(pixels), Float(pixels)] }
            let corner = BoxArithmetic.fitted(pixels, width: room.0, height: room.1)
            return [Float(corner.width), Float(corner.height)]
        }
        guard fitted != toldCorners else { return }
        toldCorners = fitted
        Java.frame { Java.call(reference, JavaAPI.setShapeCorners, .object(Java.floats(fitted))) }
    }

    /// Moves what the shape draws for the room it stands in: drawn geometry placed by its aspect, then moved by
    /// the transform; a rectangle or an ellipse moved by the transform alone.
    /// Design: docs/design/host/layout.md#a-shapes-own-geometry
    private func place() {
        guard let size = placedSize else { return }
        let room = LayoutSize(width: Double(size.width) / density, height: Double(size.height) / density)
        let numbers = drawsGeometry
            ? ShapeArithmetic.placement(of: geometryBounds, in: room, aspect: aspect, transform: transform)
            : transform
        let affine = numbers.map { values in
            [values[0], values[1], values[2], values[3], values[4] * density, values[5] * density].map(Float.init)
        } ?? []
        guard affine != placing else { return }
        placing = affine
        Java.frame { Java.call(reference, JavaAPI.setShapePlacing, .object(Java.floats(affine))) }
    }

    /// Where Android measures the drawn geometry, in points.
    private func readGeometryBounds() -> Rect {
        var read: [Float] = [0, 0, 0, 0]
        Java.frame {
            guard let array = Java.callObject(reference, JavaAPI.shapeGeometryBounds) else { return }
            read.withUnsafeMutableBufferPointer { Java.jni.GetFloatArrayRegion(Java.env, array, 0, 4, $0.baseAddress) }
        }
        return Rect(
            x: Double(read[0]) / density, y: Double(read[1]) / density, width: Double(read[2]) / density,
            height: Double(read[3]) / density)
    }

    /// The Java side's kind, drawn geometry as commands in pixels, and fill rule; a rectangle and an ellipse fill
    /// the view.
    private static func flattened(_ geometry: Geometry, density: Double) -> (Int32, [Float], Bool) {
        switch geometry {
        case .rectangle: (0, [], false)
        case .ellipse: (1, [], false)
        case .line(let from, let to): (2, pixels([0, from.x, from.y, 1, to.x, to.y], density), false)
        case .points(let points, let closed, let evenOdd):
            (2, pixels(ShapeArithmetic.commands(through: points, closed: closed), density), evenOdd)
        case .path(let data):
            (2, pixels((HostPath(svg: data)?.arcsAsCubics ?? []).flatMap(\.numbers), density), false)
        }
    }

    /// Flat commands in points as pixels: each command's number as it is, the coordinates after it scaled.
    private static func pixels(_ commands: [Double], _ density: Double) -> [Float] {
        var drawn: [Float] = []
        var index = 0
        while index < commands.count {
            let command = commands[index]
            let coordinates = switch command {
            case 0, 1: 2
            case 2: 6
            case 3: 4
            default: 0
            }
            drawn.append(Float(command))
            drawn += commands.dropFirst(index + 1).prefix(coordinates).map { Float($0 * density) }
            index += 1 + coordinates
        }
        return drawn
    }
}
