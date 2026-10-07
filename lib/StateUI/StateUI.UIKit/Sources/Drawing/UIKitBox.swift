// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout's box: its backdrop, its fill within its outline, the outline's stroke inside its edge, all behind the
/// children - by their depth, whatever their order - and the cut of what the layout shows to the outline, each a
/// layer made only while there is something to paint. Over a backdrop the fill and the stroke are the backdrop's.
/// Design: docs/design/platforms/uikit/drawing.md#a-layouts-box
@MainActor
struct UIKitBox {
    private var fill = UIKitBrush()
    private var stroke = UIKitBrush()
    private var width = 0.0
    private var outline = ContainerShape.rectangle
    private var clips = false
    private var backdrop: HostBackdrop?

    private var fillLayer: CALayer?
    private(set) var backdropView: UIKitBackdropView?
    private var strokeLayer: CAShapeLayer?
    private var painted: (size: CGSize, generation: Int)?
    private var generation = 0

    /// Takes what the tree says of the box, by the host layer's reading of it (`BoxArithmetic`).
    mutating func set(
        backdrop: HostValue?, fill: HostValue?, stroke: HostValue?, width: Double?, shape: HostValue?, clips: Bool
    ) {
        self.backdrop = HostBackdrop(backdrop)
        self.fill = UIKitBrush(fill)
        self.stroke = UIKitBrush(stroke)
        self.width = BoxArithmetic.outlineWidth(stroke: stroke, width: width)
        outline = BoxArithmetic.outline(shape)
        self.clips = clips
        generation += 1
    }

    /// Paints the box on `view` for its size, where the size or the box changed since it last did.
    mutating func paint(on view: UIView) {
        let size = view.bounds.size
        guard painted.map({ $0.size != size || $0.generation != generation }) ?? (generation > 0) else { return }
        painted = (size, generation)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        defer { CATransaction.commit() }

        let bounds = view.bounds
        let path = outline.path(in: bounds)
        if let backdrop {
            let shown = backdropView ?? UIKitBackdropView()
            if backdropView == nil { view.insertSubview(shown, at: 0) }
            backdropView = shown
            shown.show(backdrop)
            shown.lay(fill, stroke: stroke, width: width, over: bounds, cut: outline)
        } else {
            backdropView?.removeFromSuperview()
            backdropView = nil
        }
        let own = backdrop == nil
        let filled = own ? fill.layer(over: bounds, reusing: fillLayer) : nil
        if filled !== fillLayer {
            fillLayer?.removeFromSuperlayer()
            filled?.zPosition = -2
            if let filled { view.layer.insertSublayer(filled, at: 0) }
        }
        fillLayer = filled
        filled?.mask = outline == .rectangle ? nil : Self.mask(path, over: bounds, reusing: filled?.mask)

        if own, width > 0, let color = stroke.lineColor {
            let line = strokeLayer ?? CAShapeLayer()
            if strokeLayer == nil {
                line.zPosition = -1
                view.layer.insertSublayer(line, at: 0)
            }
            line.frame = bounds
            line.path = outline.path(in: bounds.insetBy(dx: width / 2, dy: width / 2))
            line.lineWidth = width
            line.strokeColor = color.cgColor
            line.fillColor = nil
            strokeLayer = line
        } else {
            strokeLayer?.removeFromSuperlayer()
            strokeLayer = nil
        }

        view.clipsToBounds = clips && outline == .rectangle
        view.layer.mask = clips && outline != .rectangle ? Self.mask(path, over: bounds, reusing: view.layer.mask) : nil
    }

    /// A mask letting through what `path` holds.
    private static func mask(_ path: CGPath, over bounds: CGRect, reusing layer: CALayer?) -> CAShapeLayer {
        let mask = layer as? CAShapeLayer ?? CAShapeLayer()
        mask.frame = bounds
        mask.path = path
        return mask
    }
}
#endif
