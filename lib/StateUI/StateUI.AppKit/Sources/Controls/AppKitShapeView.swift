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
    /// Its corners' radii, clockwise from the top left.
    case rectangle([Double])
    case ellipse
    case line(x1: CGFloat, y1: CGFloat, x2: CGFloat, y2: CGFloat)
    case path(String)
    case points([Double], fillRule: Int32)
}

/// Native drawing surface for StateUI's shape family. Geometry is kept as a
/// value and rebuilt from the current bounds, so a resize and a host-driven
/// transition always produce the same path from the same inputs; a geometry of
/// its own numbers stands in the room by the host layer's rule (`ShapeArithmetic`).
/// Design: docs/design/host/layout.md#a-shapes-own-geometry
@MainActor
final class AppKitShapeView: AppKitHitTestView {
    let kind: AppKitShapeKind

    private var fill = AppKitBrush()
    private var stroke = AppKitBrush()
    private var lineWidth: CGFloat = 1
    private var dash: [Double] = []
    private var dashOffset: CGFloat = 0
    private var lineCap: Int32 = 0
    private var lineJoin: Int32 = 0
    private var miterLimit: CGFloat = 10
    private var aspect = ContentMode.fit
    private var renderTransform: [Double]?
    private var geometry: AppKitShapeGeometry

    init(kind: AppKitShapeKind) {
        self.kind = kind
        switch kind {
        case .rectangle: geometry = .rectangle([0, 0, 0, 0])
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
        lineWidth: Double?,
        dash: [Double],
        dashOffset: Double,
        lineCap: Int32,
        lineJoin: Int32,
        miterLimit: Double,
        aspect: ContentMode,
        renderTransform: [Double]?,
        geometry: AppKitShapeGeometry
    ) {
        self.fill = AppKitBrush(fill)
        self.stroke = AppKitBrush(stroke)
        self.lineWidth = CGFloat(BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth))
        self.dash = dash
        self.dashOffset = dashOffset.isFinite ? CGFloat(dashOffset) : 0
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = max(0, miterLimit.isFinite ? CGFloat(miterLimit) : 0)
        self.aspect = aspect
        self.renderTransform = renderTransform
        self.geometry = geometry
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        let path = pathForTesting(in: bounds)
        fill.draw(in: path, bounds: bounds)
        stroke.stroke(path, width: lineWidth)
    }

    func pathForTesting(in bounds: NSRect) -> NSBezierPath {
        let path: NSBezierPath
        let stretchesAuthoredGeometry: Bool

        switch geometry {
        case .rectangle(let radii):
            let rect = bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2)
            path = NSBezierPath(cgPath: AppKitCorners.path(in: rect, clockwise: radii))
            stretchesAuthoredGeometry = false

        case .ellipse:
            path = NSBezierPath(ovalIn: bounds.insetBy(dx: lineWidth / 2, dy: lineWidth / 2))
            stretchesAuthoredGeometry = false

        case .line(let x1, let y1, let x2, let y2):
            path = NSBezierPath()
            path.move(to: NSPoint(x: x1, y: y1))
            path.line(to: NSPoint(x: x2, y: y2))
            stretchesAuthoredGeometry = true

        case .points(let values, let fillRule):
            path = Self.pointsPath(values, closed: kind == .polygon)
            path.windingRule = fillRule == 0 ? .evenOdd : .nonZero
            stretchesAuthoredGeometry = true

        case .path(let data):
            path = Self.svgPath(data)
            stretchesAuthoredGeometry = true
        }

        configureStroke(on: path)
        guard stretchesAuthoredGeometry else { return moved(path, by: renderTransform) }
        guard path.elementCount > 0 else { return path }

        let drawn = path.bounds
        let placed = ShapeArithmetic.placement(
            of: Rect(Double(drawn.minX), Double(drawn.minY), Double(drawn.width), Double(drawn.height)),
            in: LayoutSize(width: Double(bounds.width), height: Double(bounds.height)), aspect: aspect,
            transform: renderTransform)
        return moved(path, by: placed)
    }

    /// `path` moved by a transform's six numbers - `a, b, c, d, tx, ty` - from its room's top left; as it stands
    /// where there are none.
    private func moved(_ path: NSBezierPath, by numbers: [Double]?) -> NSBezierPath {
        guard let numbers, numbers.count == 6, numbers.allSatisfy(\.isFinite) else { return path }
        var transform = CGAffineTransform(
            a: numbers[0], b: numbers[1], c: numbers[2], d: numbers[3], tx: numbers[4], ty: numbers[5])
        guard let moved = path.cgPath.copy(using: &transform) else { return path }
        let result = NSBezierPath(cgPath: moved)
        result.windingRule = path.windingRule
        configureStroke(on: result)
        return result
    }

    var dashPatternForTesting: [CGFloat] {
        ShapeArithmetic.dashLengths(dash, lineWidth: Double(lineWidth)).map { CGFloat($0) }
    }
    var dashPhaseForTesting: CGFloat { dashOffset * lineWidth }

    private func configureStroke(on path: NSBezierPath) {
        path.lineWidth = lineWidth
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

    /// Points - x and y in turn - joined by lines as the host layer joins them, closed where the shape is.
    private static func pointsPath(_ values: [Double], closed: Bool) -> NSBezierPath {
        let points = stride(from: 0, to: values.count - 1, by: 2).map { Point(values[$0], values[$0 + 1]) }
        let path = CGMutablePath()
        append(ShapeArithmetic.curves(through: points, closed: closed), to: path)
        return NSBezierPath(cgPath: path)
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

    private static func cgPoint(_ point: Point) -> CGPoint {
        CGPoint(x: point.x, y: point.y)
    }
}

#endif
