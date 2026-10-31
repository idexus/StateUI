// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// One of the six shapes: its geometry drawn for the room its layout gives it by shape layers, filled and outlined
/// by their brushes - a gradient through a layer the shape cuts out.
/// Design: docs/design/platforms/uikit/drawing.md#the-shapes
@MainActor
final class UIKitShapeView: UIView, UIKitSteppable {
    /// What a reader's step performs, while the element says it is adjustable.
    var stepAction: ((AccessibilityAdjustment) -> Void)?

    override func accessibilityIncrement() { stepAction?(.increment) }

    override func accessibilityDecrement() { stepAction?(.decrement) }

    /// What the shape draws: a rectangle, its corners clockwise from the top left, or an ellipse, filling its room;
    /// or a geometry of its own, placed by its aspect - each moved by its transform.
    enum Geometry: Equatable {
        case rectangle([Double], transform: [Double]?)
        case ellipse(transform: [Double]?)
        case authored([HostCurveCommand], evenOdd: Bool, aspect: StateUI.ContentMode, transform: [Double]?)
    }

    /// How the outline is drawn: its width, its dashes and gaps with their offset in widths, its ends and joins.
    struct Outline: Equatable {
        var width = 1.0
        var dashes: [Double] = []
        var dashOffset = 0.0
        var cap = LineCap.flat
        var join = LineJoin.miter
        var miter = 10.0
    }

    private var geometry = Geometry.rectangle([0, 0, 0, 0], transform: nil)
    private var fill = UIKitBrush()
    private var stroke = UIKitBrush()
    private var outline = Outline()

    private var fillLayer: CALayer?
    private var strokeLayer: CALayer?

    /// What the fill is made of, by the host layer's reading of it; its blur or glass stands under the figure.
    private var material = HostMaterial(nil)
    private var backdrop: UIKitBackdropView?

    var fillForTesting: UIKitBrush { fill }
    var backdropForTesting: UIKitBackdropView? { backdrop }

    init() {
        super.init(frame: .zero)
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitShapeView is made in code")
    }

    /// How the shape is filled - a paint, or a blur or glass with its tint - and outlined.
    func paint(fill material: HostMaterial, stroke: UIKitBrush, outline: Outline) {
        var outline = outline
        outline.width = ShapeArithmetic.lineWidth(outline.width)
        let fill = UIKitBrush(material.paint)
        guard material != self.material || fill != self.fill || stroke != self.stroke || outline != self.outline
        else { return }
        (self.material, self.fill, self.stroke, self.outline) = (material, fill, stroke, outline)
        setNeedsLayout()
    }

    /// What the shape draws, for whatever room it is given.
    func draw(_ geometry: Geometry) {
        guard geometry != self.geometry else { return }
        self.geometry = geometry
        setNeedsLayout()
    }

    /// A shape has no size of its own: it takes the room its layout gives it.
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let outlined = !stroke.isEmpty && outline.width > 0
        let room = room(outlined: outlined)
        let shaped = path(in: room)
        showBackdrop(cut: shaped, in: room)
        // A blur's tint is painted over it; a glass's is the glass's own.
        let wash = backdrop?.showsGlass == true ? UIKitBrush() : fill
        fillLayer = paint(wash, over: shaped, stroked: false, reusing: fillLayer)
        strokeLayer = paint(outlined ? stroke : UIKitBrush(), over: shaped, stroked: true, reusing: strokeLayer)
    }

    /// The fill's blur or glass under the figure drawn in `room` - glass the rounded rectangle the figure is, a blur
    /// and any other glass cut to its path; none where the fill is a paint.
    /// Design: docs/design/platforms/uikit/drawing.md#a-figure-made-of-a-material
    private func showBackdrop(cut shaped: (path: CGPath, evenOdd: Bool)?, in room: CGRect) {
        guard let shaped, material.blur != nil else {
            backdrop?.removeFromSuperview()
            backdrop = nil
            return
        }
        let shown = backdrop ?? UIKitBackdropView()
        if backdrop == nil { insertSubview(shown, at: 0) }
        backdrop = shown
        let corners = material.glass == nil ? nil : rounded(in: room)
        shown.frame = corners == nil ? bounds : room
        shown.show(material, as: corners.map { .rounded($0) } ?? .cut(shaped.path, evenOdd: shaped.evenOdd))
    }

    /// The corners, clockwise from the top left, of the rounded rectangle the figure is in `room`: a rectangle's,
    /// an oval's where it is a circle; nil for an oval of two lengths, a geometry of its own, or a turned figure.
    private func rounded(in room: CGRect) -> [Double]? {
        switch geometry {
        case .rectangle(let radii, transform: nil): Self.corners(radii, in: room)
        case .ellipse(transform: nil):
            BoxArithmetic.roundedCorners(of: .ellipse, width: room.width, height: room.height)
        default: nil
        }
    }

    /// A rectangle's radii in `room`: none past half its shorter side.
    private static func corners(_ radii: [Double], in room: CGRect) -> [Double] {
        radii.map { BoxArithmetic.fitted($0.isFinite ? max(0, $0) : 0, width: room.width, height: room.height) }
    }

    /// The layer painting `brush` over the path - inside it, or along it - made anew or kept.
    private func paint(
        _ brush: UIKitBrush, over shaped: (path: CGPath, evenOdd: Bool)?, stroked: Bool, reusing kept: CALayer?
    ) -> CALayer? {
        guard let shaped, !brush.isEmpty else {
            kept?.removeFromSuperlayer()
            return nil
        }
        let cut = CAShapeLayer()
        cut.path = shaped.path
        cut.fillRule = shaped.evenOdd ? .evenOdd : .nonZero
        if stroked {
            cut.fillColor = nil
            cut.strokeColor = UIColor.black.cgColor
            cut.lineWidth = outline.width
            cut.lineCap = switch outline.cap {
            case .flat: .butt
            case .round: .round
            case .square: .square
            }
            cut.lineJoin = switch outline.join {
            case .miter: .miter
            case .round: .round
            case .bevel: .bevel
            }
            cut.miterLimit = outline.miter
            let lengths = ShapeArithmetic.dashLengths(outline.dashes, lineWidth: outline.width)
            cut.lineDashPattern = lengths.contains { $0 > 0 } ? lengths.map { NSNumber(value: $0) } : nil
            cut.lineDashPhase = outline.dashOffset * outline.width
        } else {
            cut.fillColor = UIColor.black.cgColor
        }
        // The brush over the whole room and its outline's reach, cut to the shape.
        let reach = bounds.insetBy(dx: -outline.width, dy: -outline.width)
        let painted = brush.layer(over: reach, reusing: kept) ?? CALayer()
        cut.frame = CGRect(origin: CGPoint(x: -reach.minX, y: -reach.minY), size: bounds.size)
        painted.mask = cut
        if painted !== kept {
            kept?.removeFromSuperlayer()
            layer.addSublayer(painted)
        }
        return painted
    }

    /// The room a rectangle and an ellipse fill: the view's, half their outline in from its edges.
    private func room(outlined: Bool) -> CGRect {
        let inset = outlined ? outline.width / 2 : 0
        return bounds.insetBy(dx: min(inset, bounds.width / 2), dy: min(inset, bounds.height / 2))
    }

    /// The path for the view: a rectangle and an ellipse fill `room`; a geometry of the shape's own is placed in the
    /// view. Whether it fills by the even-odd rule.
    private func path(in room: CGRect) -> (path: CGPath, evenOdd: Bool)? {
        switch geometry {
        case .rectangle(let radii, let transform):
            let corners = Self.corners(radii, in: room).map { CGSize(width: $0, height: $0) }
            return (Self.moved(.rounded(room, corners: corners), by: transform), false)
        case .ellipse(let transform):
            return (Self.moved(CGPath(ellipseIn: room, transform: nil), by: transform), false)
        case .authored(let curves, let evenOdd, let aspect, let transform):
            let own = Self.path(curves)
            guard !own.isEmpty else { return nil }
            let drawn = own.boundingBoxOfPath
            let placed = ShapeArithmetic.placement(
                of: Rect(x: drawn.minX, y: drawn.minY, width: drawn.width, height: drawn.height),
                in: LayoutSize(width: bounds.width, height: bounds.height), aspect: aspect, transform: transform)
            return (Self.moved(own, by: placed), evenOdd)
        }
    }

    /// `path` moved by an affine transform's six numbers - `a, b, c, d, tx, ty` - from its room's top left; as it
    /// stands where there are none.
    private static func moved(_ path: CGPath, by numbers: [Double]?) -> CGPath {
        guard let numbers, numbers.count == 6 else { return path }
        var transform = CGAffineTransform(
            a: numbers[0], b: numbers[1], c: numbers[2], d: numbers[3], tx: numbers[4], ty: numbers[5])
        return path.copy(using: &transform) ?? path
    }

    /// The path the commands draw.
    static func path(_ curves: [HostCurveCommand]) -> CGPath {
        let path = CGMutablePath()
        func point(_ point: Point) -> CGPoint { CGPoint(x: point.x, y: point.y) }
        for curve in curves {
            switch curve {
            case .move(let to): path.move(to: point(to))
            case .line(let to): path.addLine(to: point(to))
            case .cubic(let first, let second, let end):
                path.addCurve(to: point(end), control1: point(first), control2: point(second))
            case .quadratic(let control, let end): path.addQuadCurve(to: point(end), control: point(control))
            case .close: path.closeSubpath()
            }
        }
        return path
    }
}
#endif
