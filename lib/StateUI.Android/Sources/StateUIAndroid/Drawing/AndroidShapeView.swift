// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
import CStateUIAndroid

/// A Rectangle, an Ellipse, a Line, a Path, a Polygon or a Polyline: the host's `StateUIShapeView`, told its
/// geometry, brush, outline and placement one call each.
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

    /// Everything the shape draws, from what the tree says.
    func draw(
        _ geometry: Geometry, fill: HostValue?, stroke: HostValue?, strokeWidth: Double, dashes: [Double],
        dashOffset: Double, cap: Int32, join: Int32, miterLimit: Double, aspect: Int32, transform: [Double]?
    ) {
        let (kind, corners, commands, evenOdd) = Self.flattened(geometry, density: density)
        Java.frame {
            Java.call(
                reference, JavaAPI.setShapeGeometry, .int(kind), .object(Java.floats(corners)),
                .object(Java.floats(commands)), .bool(evenOdd))

            let brush = AndroidShapeDrawable.brush(fill)
            Java.call(
                reference, JavaAPI.setShapeFill, .int(brush.kind), .object(Java.ints(brush.colors)),
                .object(Java.floats(brush.offsets)), .object(Java.floats(brush.geometry)))

            // Dashes are counted in the outline's own width, as StateUI's are.
            let width = strokeWidth.isFinite ? max(0, strokeWidth) : 0
            let argb = stroke.flatMap { AndroidView.argb($0) ?? $0.values?.lazy.compactMap(AndroidView.argb).first }
            Java.call(
                reference, JavaAPI.setShapeStroke, .int(argb ?? 0), .float(argb == nil ? 0 : Float(width * density)),
                .object(Java.floats(dashes.map { Float(max(0, $0) * width * density) })),
                .float(Float(dashOffset * width * density)), .int(cap), .int(join), .float(Float(max(0, miterLimit))))

            let affine = transform.map { values in
                [values[0], values[1], values[2], values[3], values[4] * density, values[5] * density].map(Float.init)
            }
            Java.call(reference, JavaAPI.setShapePlacement, .int(aspect), .object(Java.floats(affine ?? [])))
        }
    }

    /// The Java side's kind, corners and commands in pixels, and fill rule.
    private static func flattened(_ geometry: Geometry, density: Double) -> (Int32, [Float], [Float], Bool) {
        func at(_ point: Point) -> [Float] { [Float(point.x * density), Float(point.y * density)] }

        switch geometry {
        case .rectangle(let radius):
            guard case .rounded(let radii) = AndroidShapeDrawable.Shape(corners: radius?.propValue) else {
                return (0, [0, 0, 0, 0], [], false)
            }
            return (0, radii.map { Float($0 * density) }, [], false)
        case .ellipse:
            return (1, [], [], false)
        case .line(let from, let to):
            return (2, [], [0] + at(from) + [1] + at(to), false)
        case .points(let points, let closed, let evenOdd):
            let finite = points.filter { $0.x.isFinite && $0.y.isFinite }
            guard let first = finite.first else { return (2, [], [], evenOdd) }
            let drawn = [0] + at(first) + finite.dropFirst().flatMap { [1] + at($0) } + (closed ? [4] : [])
            return (2, [], drawn, evenOdd)
        case .path(let data):
            let commands = HostPath(svg: data)?.arcsAsCubics ?? []
            let drawn: [Float] = commands.flatMap { command -> [Float] in
                switch command {
                case .move(let point): [0] + at(point)
                case .line(let point): [1] + at(point)
                case .cubic(let first, let second, let end): [2] + at(first) + at(second) + at(end)
                case .quadratic(let control, let end): [3] + at(control) + at(end)
                case .close: [4]
                }
            }
            return (2, [], drawn, false)
        }
    }
}
