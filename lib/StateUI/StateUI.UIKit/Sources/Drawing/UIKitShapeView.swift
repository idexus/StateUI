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
final class UIKitShapeView: UIView {
    /// What the shape draws: a rectangle, its corners clockwise from the top left, or an ellipse, filling its room;
    /// or a geometry of its own, placed by its aspect - each moved by its transform.
    enum Geometry: Equatable {
        case rectangle([Double], transform: [Double]?)
        case ellipse(transform: [Double]?)
        case authored([HostCurveCommand], evenOdd: Bool, aspect: ContentMode, transform: [Double]?)
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

    init() {
        super.init(frame: .zero)
        isOpaque = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitShapeView is made in code")
    }

    /// How the shape is filled and outlined.
    func paint(fill: UIKitBrush, stroke: UIKitBrush, outline: Outline) {
        var outline = outline
        outline.width = ShapeArithmetic.lineWidth(outline.width)
        guard fill != self.fill || stroke != self.stroke || outline != self.outline else { return }
        (self.fill, self.stroke, self.outline) = (fill, stroke, outline)
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
        let shaped = path(outlined: outlined)
        fillLayer = paint(fill, over: shaped, stroked: false, reusing: fillLayer)
        strokeLayer = paint(outlined ? stroke : UIKitBrush(), over: shaped, stroked: true, reusing: strokeLayer)
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

    /// The path for the view's room: a rectangle and an ellipse fill it, half their outline in from its edges; a
    /// geometry of the shape's own is placed in it. Whether it fills by the even-odd rule.
    private func path(outlined: Bool) -> (path: CGPath, evenOdd: Bool)? {
        let inset = outlined ? outline.width / 2 : 0
        let room = bounds.insetBy(dx: min(inset, bounds.width / 2), dy: min(inset, bounds.height / 2))
        switch geometry {
        case .rectangle(let radii, let transform):
            let limit = min(room.width, room.height) / 2
            let corners = radii.map { radius in
                let kept = min(radius.isFinite ? max(0, radius) : 0, limit)
                return CGSize(width: kept, height: kept)
            }
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
