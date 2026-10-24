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
    /// What the fill is made of, by the host layer's reading of it: a paint, or a blur or glass with its tint.
    private var material = HostMaterial(nil)
    /// The blur or glass the figure is made of, cut to it; nil where the figure is painted.
    private(set) var surface: (any AppKitBoxSurface)?
    /// The outline drawn over the surface, where there is one.
    private var outline: AppKitShapeOutline?
    private var stroke = AppKitBrush()
    private var lineWidth: CGFloat = 1
    private var dash: [Double] = []
    private var dashOffset: CGFloat = 0
    private var lineCap: Int32 = 0
    private var lineJoin: Int32 = 0
    private var miterLimit: CGFloat = 10
    private var aspect = ContentMode.fit
    private var geometryTransform: [Double]?
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
        geometryTransform: [Double]?,
        geometry: AppKitShapeGeometry
    ) {
        material = HostMaterial(fill)
        self.fill = AppKitBrush(material.paint)
        self.stroke = AppKitBrush(stroke)
        self.lineWidth = CGFloat(BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth))
        self.dash = dash
        self.dashOffset = dashOffset.isFinite ? CGFloat(dashOffset) : 0
        self.lineCap = lineCap
        self.lineJoin = lineJoin
        self.miterLimit = max(0, miterLimit.isFinite ? CGFloat(miterLimit) : 0)
        self.aspect = aspect
        self.geometryTransform = geometryTransform
        self.geometry = geometry
        showSurface()
        needsDisplay = true
        outline?.needsDisplay = true
    }

    /// Lays the fill's glass - in its tint - or its blur - its tint over it - under the figure's outline, cut to the
    /// figure; takes it away where the fill is a paint.
    /// Design: docs/design/platforms/appkit/views.md#a-figure-made-of-a-material
    private func showSurface() {
        if let glass = material.glass {
            let shown = surface as? AppKitGlassView ?? place(AppKitGlassView())
            shown.show(glass, tint: material.paint.flatMap(nsColor))
        } else if let thickness = material.blur {
            let shown = surface as? AppKitMaterialView ?? place(AppKitMaterialView(thickness, behindWindow: false))
            shown.material = AppKitMaterialView.role(thickness)
            shown.wash.fill = fill
        } else {
            surface?.removeFromSuperview()
            outline?.removeFromSuperview()
            (surface, outline) = (nil, nil)
            return
        }
        if outline == nil {
            let made = AppKitShapeOutline(self)
            addSubview(made, positioned: .above, relativeTo: surface)
            outline = made
        }
        cutSurface()
    }

    /// Lays `made` lowest in the view, in place of the surface it held.
    private func place<Surface: AppKitBoxSurface>(_ made: Surface) -> Surface {
        surface?.removeFromSuperview()
        made.wantsLayer = true
        addSubview(made, positioned: .below, relativeTo: nil)
        surface = made
        return made
    }

    /// Fits the surface to the figure: the view's whole room, cut by the figure's path.
    private func cutSurface() {
        guard let surface else { return }
        surface.frame = bounds
        outline?.frame = bounds
        guard let layer = surface.layer else { return }
        var path = pathForTesting(in: bounds).cgPath
        if !surface.isFlipped {
            var flip = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: bounds.height)
            path = path.copy(using: &flip) ?? path
        }
        let mask = layer.mask as? CAShapeLayer ?? CAShapeLayer()
        mask.frame = CGRect(origin: .zero, size: bounds.size)
        mask.fillRule = pathForTesting(in: bounds).windingRule == .evenOdd ? .evenOdd : .nonZero
        mask.path = path
        layer.mask = mask
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        cutSurface()
    }

    /// Strokes the figure's outline within `bounds` - over its surface, from the outline drawn above it.
    func strokeOutline(in bounds: NSRect) {
        stroke.stroke(pathForTesting(in: bounds), width: lineWidth)
    }

    /// The whole of the view under a transform, which AppKit leaves out of what it takes for visible.
    override var visibleRect: NSRect { drawnRect(visible: super.visibleRect) }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard surface == nil else { return }
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
        guard stretchesAuthoredGeometry else { return moved(path, by: geometryTransform) }
        guard path.elementCount > 0 else { return path }

        let drawn = path.bounds
        let placed = ShapeArithmetic.placement(
            of: Rect(Double(drawn.minX), Double(drawn.minY), Double(drawn.width), Double(drawn.height)),
            in: LayoutSize(width: Double(bounds.width), height: Double(bounds.height)), aspect: aspect,
            transform: geometryTransform)
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
    var fillForTesting: AppKitBrush { fill }
    var cornersForTesting: [Double] {
        if case .rectangle(let radii) = geometry { radii } else { [] }
    }

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
