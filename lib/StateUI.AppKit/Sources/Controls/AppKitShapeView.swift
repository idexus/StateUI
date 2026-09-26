// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

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
    private var strokeWidth: CGFloat = 1
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
        strokeWidth: Double,
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
        self.strokeWidth = finiteNonnegative(strokeWidth)
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
        guard strokeWidth > 0 else { return }
        stroke.stroke(path, width: strokeWidth)
    }

    func pathForTesting(in bounds: NSRect) -> NSBezierPath {
        let path: NSBezierPath
        let stretchesAuthoredGeometry: Bool

        switch geometry {
        case .rectangle(let radii):
            let rect = bounds.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)
            path = NSBezierPath(cgPath: radii.path(in: rect))
            stretchesAuthoredGeometry = false

        case .ellipse:
            path = NSBezierPath(ovalIn: bounds.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2))
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

    var dashPatternForTesting: [CGFloat] { dash.map { $0 * strokeWidth } }
    var dashPhaseForTesting: CGFloat { dashOffset * strokeWidth }

    private func configureStroke(on path: NSBezierPath) {
        path.lineWidth = strokeWidth
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
        append(source.arcsAsCubics, to: path)
        return NSBezierPath(cgPath: path)
    }

    /// Draws `commands` onto `path`.
    private static func append(_ commands: [HostCurveCommand], to path: CGMutablePath) {
        for command in commands {
            switch command {
            case .move(let point):
                path.move(to: cgPoint(point))
            case .line(let point):
                path.addLine(to: cgPoint(point))
            case .cubic(let first, let second, let end):
                path.addCurve(to: cgPoint(end), control1: cgPoint(first), control2: cgPoint(second))
            case .quadratic(let control, let end):
                path.addQuadCurve(to: cgPoint(end), control: cgPoint(control))
            case .close:
                path.closeSubpath()
            }
        }
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
        append(
            HostPath.arc(
                from: Point(start.x, start.y), to: Point(end.x, end.y), radiusX: radiusX, radiusY: radiusY,
                rotation: 0, largeArc: abs(delta) > .pi, sweep: clockwise),
            to: path)
        if closed || wedge { path.closeSubpath() }
        return NSBezierPath(cgPath: path)
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
