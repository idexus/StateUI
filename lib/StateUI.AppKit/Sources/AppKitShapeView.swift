// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

enum AppKitShapeKind {
    case rectangle
    case ellipse
    case line
    case path
    case polygon
    case polyline
}

enum AppKitShapeGeometry {
    case rectangle(AppKitCornerRadii)
    case ellipse
    case line(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)
    case path(String)
    case points([Double], fillRule: Int32)
}

/// Native drawing surface for StateUI's shape family. Geometry is kept as a
/// value and rebuilt from the current bounds, so a resize and a host-driven
/// transition always produce the same path from the same inputs.
@MainActor
final class AppKitShapeView: AppKitHitTestView {
    let kind: AppKitShapeKind

    private var fill = AppKitBrush()
    private var stroke = AppKitBrush()
    private var thickness: CGFloat = 1
    private var dash: [CGFloat] = []
    private var dashOffset: CGFloat = 0
    private var lineCap: Int32 = 0
    private var lineJoin: Int32 = 0
    private var miterLimit: CGFloat = 10
    private var aspect: Int32 = 0
    private var renderTransform = CGAffineTransform.identity
    private var geometry: AppKitShapeGeometry

    init(kind: AppKitShapeKind) {
        self.kind = kind
        switch kind {
        case .rectangle: geometry = .rectangle(AppKitCornerRadii())
        case .ellipse: geometry = .ellipse
        case .line: geometry = .line(x1: 0, y1: 0, x2: 0, y2: 0)
        case .path: geometry = .path("")
        case .polygon, .polyline: geometry = .points([], fillRule: 0)
        }
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("AppKitShapeView is created in code")
    }

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { .zero }

    func apply(
        fill: HostValue?,
        stroke: HostValue?,
        thickness: Double,
        dash: [Double],
        dashOffset: Double,
        lineCap: Int32,
        lineJoin: Int32,
        miterLimit: Double,
        aspect: Int32,
        renderTransform: [Double]?,
        geometry: AppKitShapeGeometry
    ) {
        self.fill = AppKitBrush(fill) ?? AppKitBrush()
        self.stroke = AppKitBrush(stroke) ?? AppKitBrush()
        self.thickness = finiteNonnegative(thickness)
        self.dash = dash.map(finiteNonnegative)
        self.dashOffset = dashOffset.isFinite ? CGFloat(dashOffset) : 0
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = max(0, miterLimit.isFinite ? CGFloat(miterLimit) : 0)
        self.aspect = aspect
        self.renderTransform = affine(renderTransform)
        self.geometry = geometry
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = pathForTesting(in: bounds)
        fill.draw(in: path, bounds: bounds)
        guard thickness > 0 else { return }
        stroke.stroke(path, width: thickness)
    }

    func pathForTesting(in bounds: NSRect) -> NSBezierPath {
        let path: NSBezierPath
        let stretchesAuthoredGeometry: Bool

        switch geometry {
        case .rectangle(let radii):
            let rect = bounds.insetBy(dx: thickness / 2, dy: thickness / 2)
            path = NSBezierPath(cgPath: radii.path(in: rect))
            stretchesAuthoredGeometry = false

        case .ellipse:
            path = NSBezierPath(ovalIn: bounds.insetBy(dx: thickness / 2, dy: thickness / 2))
            stretchesAuthoredGeometry = false

        case .line(let x1, let y1, let x2, let y2):
            path = NSBezierPath()
            path.move(to: NSPoint(x: x1, y: y1))
            path.line(to: NSPoint(x: x2, y: y2))
            stretchesAuthoredGeometry = true

        case .points(let values, let fillRule):
            path = pointsPath(values)
            if kind == .polygon { path.close() }
            path.windingRule = fillRule == 0 ? .evenOdd : .nonZero
            stretchesAuthoredGeometry = true

        case .path(let data):
            path = Self.svgPath(data)
            stretchesAuthoredGeometry = true
        }

        configureStroke(on: path)
        guard stretchesAuthoredGeometry else { return path }

        // The aspect places the authored drawing in the room, and the render
        // transform then moves what was drawn - as a transform moves a view
        // after its layout - so a translation shows under every aspect.
        let placed = applyingAspect(to: path, in: bounds)
        return applying(renderTransform, to: placed)
    }

    var dashPatternForTesting: [CGFloat] { dash.map { $0 * thickness } }
    var dashPhaseForTesting: CGFloat { dashOffset * thickness }

    private func configureStroke(on path: NSBezierPath) {
        path.lineWidth = thickness
        path.lineCapStyle = switch lineCap {
        case 1: .round
        case 2: .square
        default: .butt
        }
        path.lineJoinStyle = switch lineJoin {
        case 1: .bevel
        case 2: .round
        default: .miter
        }
        path.miterLimit = miterLimit
        let pattern = dashPatternForTesting
        path.setLineDash(pattern, count: pattern.count, phase: dashPhaseForTesting)
    }

    private func pointsPath(_ values: [Double]) -> NSBezierPath {
        let path = NSBezierPath()
        guard values.count >= 2 else { return path }

        let points = stride(from: 0, to: values.count - 1, by: 2).compactMap { index -> NSPoint? in
            guard values[index].isFinite, values[index + 1].isFinite else { return nil }
            return NSPoint(x: values[index], y: values[index + 1])
        }
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.line(to: point) }
        return path
    }

    static func svgPath(_ data: String) -> NSBezierPath {
        guard let source = HostPath(svg: data) else { return NSBezierPath() }
        let path = CGMutablePath()
        var current = CGPoint.zero
        var subpathStart = CGPoint.zero

        for command in source.commands {
            switch command {
            case .move(let point):
                current = cgPoint(point)
                subpathStart = current
                path.move(to: current)

            case .line(let point):
                current = cgPoint(point)
                path.addLine(to: current)

            case .cubic(let first, let second, let end):
                current = cgPoint(end)
                path.addCurve(
                    to: current,
                    control1: cgPoint(first),
                    control2: cgPoint(second))

            case .quadratic(let control, let end):
                current = cgPoint(end)
                path.addQuadCurve(to: current, control: cgPoint(control))

            case .arc(
                let radiusX,
                let radiusY,
                let rotation,
                let largeArc,
                let sweep,
                let end):
                let destination = cgPoint(end)
                appendArc(
                    to: path,
                    from: current,
                    to: destination,
                    radiusX: CGFloat(radiusX),
                    radiusY: CGFloat(radiusY),
                    rotation: CGFloat(rotation),
                    largeArc: largeArc,
                    sweep: sweep)
                current = destination

            case .close:
                path.closeSubpath()
                current = subpathStart
            }
        }

        return NSBezierPath(cgPath: path)
    }

    static func ellipseArcPath(
        in rect: NSRect,
        startAngle: CGFloat,
        endAngle: CGFloat,
        clockwise: Bool,
        closed: Bool,
        wedge: Bool
    ) -> NSBezierPath {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radiusX = abs(rect.width) / 2
        let radiusY = abs(rect.height) / 2
        let startRadians = startAngle * .pi / 180
        var endRadians = endAngle * .pi / 180
        if clockwise {
            while endRadians < startRadians { endRadians += 2 * .pi }
        } else {
            while endRadians > startRadians { endRadians -= 2 * .pi }
        }
        let delta = endRadians - startRadians
        let start = CGPoint(
            x: center.x + radiusX * cos(startRadians),
            y: center.y + radiusY * sin(startRadians))
        let end = CGPoint(
            x: center.x + radiusX * cos(endRadians),
            y: center.y + radiusY * sin(endRadians))
        let path = CGMutablePath()
        if wedge {
            path.move(to: center)
            path.addLine(to: start)
        } else {
            path.move(to: start)
        }
        appendArc(
            to: path,
            from: start,
            to: end,
            radiusX: radiusX,
            radiusY: radiusY,
            rotation: 0,
            largeArc: abs(delta) > .pi,
            sweep: clockwise)
        if closed || wedge { path.closeSubpath() }
        return NSBezierPath(cgPath: path)
    }

    private static func appendArc(
        to path: CGMutablePath,
        from start: CGPoint,
        to end: CGPoint,
        radiusX initialRadiusX: CGFloat,
        radiusY initialRadiusY: CGFloat,
        rotation: CGFloat,
        largeArc: Bool,
        sweep: Bool
    ) {
        guard start != end, initialRadiusX > 0, initialRadiusY > 0 else {
            path.addLine(to: end)
            return
        }

        let angle = rotation * .pi / 180
        let cosine = cos(angle)
        let sine = sin(angle)
        let halfX = (start.x - end.x) / 2
        let halfY = (start.y - end.y) / 2
        let transformedX = cosine * halfX + sine * halfY
        let transformedY = -sine * halfX + cosine * halfY

        var radiusX = abs(initialRadiusX)
        var radiusY = abs(initialRadiusY)
        let radiiScale = transformedX * transformedX / (radiusX * radiusX)
            + transformedY * transformedY / (radiusY * radiusY)
        if radiiScale > 1 {
            let scale = sqrt(radiiScale)
            radiusX *= scale
            radiusY *= scale
        }

        let rx2 = radiusX * radiusX
        let ry2 = radiusY * radiusY
        let x2 = transformedX * transformedX
        let y2 = transformedY * transformedY
        let numerator = max(0, rx2 * ry2 - rx2 * y2 - ry2 * x2)
        let denominator = rx2 * y2 + ry2 * x2
        let sign: CGFloat = largeArc == sweep ? -1 : 1
        let coefficient = denominator > 0 ? sign * sqrt(numerator / denominator) : 0
        let centerXPrime = coefficient * radiusX * transformedY / radiusY
        let centerYPrime = coefficient * -radiusY * transformedX / radiusX
        let center = CGPoint(
            x: cosine * centerXPrime - sine * centerYPrime + (start.x + end.x) / 2,
            y: sine * centerXPrime + cosine * centerYPrime + (start.y + end.y) / 2)

        let startVector = CGPoint(
            x: (transformedX - centerXPrime) / radiusX,
            y: (transformedY - centerYPrime) / radiusY)
        let endVector = CGPoint(
            x: (-transformedX - centerXPrime) / radiusX,
            y: (-transformedY - centerYPrime) / radiusY)
        var startAngle = vectorAngle(from: CGPoint(x: 1, y: 0), to: startVector)
        var delta = vectorAngle(from: startVector, to: endVector)
        if !sweep, delta > 0 { delta -= 2 * .pi }
        if sweep, delta < 0 { delta += 2 * .pi }

        let segments = max(1, Int(ceil(abs(delta) / (.pi / 2))))
        let segmentAngle = delta / CGFloat(segments)
        for index in 0..<segments {
            let nextAngle = startAngle + segmentAngle
            let alpha = 4 / 3 * tan(segmentAngle / 4)
            let first = arcPoint(
                center: center,
                radiusX: radiusX,
                radiusY: radiusY,
                rotationCosine: cosine,
                rotationSine: sine,
                angle: startAngle)
            let last = index == segments - 1
                ? end
                : arcPoint(
                    center: center,
                    radiusX: radiusX,
                    radiusY: radiusY,
                    rotationCosine: cosine,
                    rotationSine: sine,
                    angle: nextAngle)
            let firstDerivative = arcDerivative(
                radiusX: radiusX,
                radiusY: radiusY,
                rotationCosine: cosine,
                rotationSine: sine,
                angle: startAngle)
            let lastDerivative = arcDerivative(
                radiusX: radiusX,
                radiusY: radiusY,
                rotationCosine: cosine,
                rotationSine: sine,
                angle: nextAngle)
            path.addCurve(
                to: last,
                control1: CGPoint(
                    x: first.x + alpha * firstDerivative.x,
                    y: first.y + alpha * firstDerivative.y),
                control2: CGPoint(
                    x: last.x - alpha * lastDerivative.x,
                    y: last.y - alpha * lastDerivative.y))
            startAngle = nextAngle
        }
    }

    private static func vectorAngle(from first: CGPoint, to second: CGPoint) -> CGFloat {
        let cross = first.x * second.y - first.y * second.x
        let dot = first.x * second.x + first.y * second.y
        return atan2(cross, dot)
    }

    private static func arcPoint(
        center: CGPoint,
        radiusX: CGFloat,
        radiusY: CGFloat,
        rotationCosine: CGFloat,
        rotationSine: CGFloat,
        angle: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: center.x + radiusX * cos(angle) * rotationCosine
                - radiusY * sin(angle) * rotationSine,
            y: center.y + radiusX * cos(angle) * rotationSine
                + radiusY * sin(angle) * rotationCosine)
    }

    private static func arcDerivative(
        radiusX: CGFloat,
        radiusY: CGFloat,
        rotationCosine: CGFloat,
        rotationSine: CGFloat,
        angle: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: -radiusX * sin(angle) * rotationCosine
                - radiusY * cos(angle) * rotationSine,
            y: -radiusX * sin(angle) * rotationSine
                + radiusY * cos(angle) * rotationCosine)
    }

    private static func cgPoint(_ point: Point) -> CGPoint {
        CGPoint(x: point.x, y: point.y)
    }

    private func applying(_ transform: CGAffineTransform, to path: NSBezierPath) -> NSBezierPath {
        guard !transform.isIdentity else { return path }
        var transform = transform
        guard let changed = path.cgPath.copy(using: &transform) else { return path }
        let result = NSBezierPath(cgPath: changed)
        result.windingRule = path.windingRule
        configureStroke(on: result)
        return result
    }

    /// Places the authored geometry in the room by the shape's `Aspect`, always
    /// centred: `fit` (0) scales it to fit keeping its proportions, `fill` (1)
    /// to cover, `stretch` (2) each axis on its own, and `center` (3) keeps the
    /// size its own numbers say.
    private func applyingAspect(to path: NSBezierPath, in target: NSRect) -> NSBezierPath {
        guard path.elementCount > 0 else { return path }
        let source = path.bounds
        guard source.width > 0 || source.height > 0 else { return path }

        let widthRatio = source.width > 0 ? target.width / source.width : .greatestFiniteMagnitude
        let heightRatio = source.height > 0 ? target.height / source.height : .greatestFiniteMagnitude
        let scaleX: CGFloat
        let scaleY: CGFloat
        switch aspect {
        case 2:
            scaleX = source.width > 0 ? widthRatio : 1
            scaleY = source.height > 0 ? heightRatio : 1
        case 3:
            scaleX = 1
            scaleY = 1
        case 1:
            let scale = max(
                source.width > 0 ? widthRatio : 0,
                source.height > 0 ? heightRatio : 0)
            scaleX = scale
            scaleY = scale
        default:
            let finite = [widthRatio, heightRatio].filter { $0.isFinite }
            let scale = finite.min() ?? 1
            scaleX = scale
            scaleY = scale
        }

        let drawnWidth = source.width * scaleX
        let drawnHeight = source.height * scaleY
        let originX = target.midX - drawnWidth / 2
        let originY = target.midY - drawnHeight / 2
        var transform = CGAffineTransform(
            a: scaleX,
            b: 0,
            c: 0,
            d: scaleY,
            tx: originX - source.minX * scaleX,
            ty: originY - source.minY * scaleY)
        guard let changed = path.cgPath.copy(using: &transform) else { return path }
        let result = NSBezierPath(cgPath: changed)
        result.windingRule = path.windingRule
        configureStroke(on: result)
        return result
    }

    private func affine(_ values: [Double]?) -> CGAffineTransform {
        guard let values, values.count >= 6, values.prefix(6).allSatisfy(\.isFinite) else {
            return .identity
        }
        return CGAffineTransform(
            a: values[0], b: values[1], c: values[2], d: values[3],
            tx: values[4], ty: values[5])
    }

    private func finiteNonnegative(_ value: Double) -> CGFloat {
        value.isFinite ? max(0, CGFloat(value)) : 0
    }
}

#endif
