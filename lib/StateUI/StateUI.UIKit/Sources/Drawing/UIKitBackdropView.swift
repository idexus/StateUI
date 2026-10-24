// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout's blur or glass behind what it holds - no child of it, kept beneath its children - a blur's tint laid
/// over it, in its content.
/// Design: docs/design/platforms/uikit/drawing.md#a-layouts-blur-or-glass
@MainActor
final class UIKitBackdropView: UIVisualEffectView {
    /// What it shows, as the host layer read it.
    private(set) var shown: HostMaterial?

    /// The background laid over the backdrop, and the outline over both.
    private var wash: CALayer?
    private var line: CAShapeLayer?

    /// UIKit's material for a blur's thickness: its own five.
    static func style(_ thickness: Blur.Thickness) -> UIBlurEffect.Style {
        switch thickness {
        case .ultraThin: .systemUltraThinMaterial
        case .thin: .systemThinMaterial
        case .regular: .systemMaterial
        case .thick: .systemThickMaterial
        case .ultraThick: .systemChromeMaterial
        }
    }

    init() {
        super.init(effect: nil)
        isUserInteractionEnabled = false
        clipsToBounds = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitBackdropView is made in code")
    }

    /// Whether it shows glass, whose tint is its own; a blur's is laid over it.
    var showsGlass: Bool { shown?.glass != nil }

    /// The figure a backdrop stands as across its frame: a rounded rectangle, its corners clockwise from the top
    /// left, or any other, cut by a path.
    enum Figure {
        case rounded([Double])
        case cut(CGPath, evenOdd: Bool)
    }

    /// Shows `material` as `figure`: a rounded rectangle of its glass in its tint, or of its blur, by the view's own
    /// corners - a capsule's ends round whole; any other figure of its blur - glass's the one standing in for it,
    /// as glass keeps to no mask - cut by a mask.
    /// Design: docs/design/platforms/uikit/drawing.md#glass-takes-its-corners
    func show(_ material: HostMaterial, as figure: Figure) {
        switch figure {
        case .rounded(let corners) where corners.count == 4:
            showEffect(material)
            layer.mask = nil
            let half = min(bounds.width, bounds.height) / 2
            cornerConfiguration = corners.allSatisfy({ abs($0 - half) < 0.01 }) ? .capsule() : .corners(
                topLeftRadius: .fixed(corners[0]), topRightRadius: .fixed(corners[1]),
                bottomLeftRadius: .fixed(corners[3]), bottomRightRadius: .fixed(corners[2]))
        case .rounded:
            show(material, as: .rounded([0, 0, 0, 0]))
        case .cut(let path, let evenOdd):
            showEffect(material.withoutGlass)
            cornerConfiguration = .corners(radius: .fixed(0))
            let mask = layer.mask as? CAShapeLayer ?? CAShapeLayer()
            mask.frame = CGRect(origin: .zero, size: bounds.size)
            mask.path = path
            mask.fillRule = evenOdd ? .evenOdd : .nonZero
            layer.mask = mask
        }
    }

    /// Shows `material` - glass, in its tint, where it asks for glass, else its blur - where it changed.
    private func showEffect(_ material: HostMaterial) {
        guard material != shown, let thickness = material.blur else { return }
        shown = material
        if let glass = material.glass {
            let effect = UIGlassEffect(style: glass.isClear ? .clear : .regular)
            effect.tintColor = material.paint.flatMap(UIColor.init(stateUI:))
            effect.isInteractive = glass.isInteractive
            self.effect = effect
        } else {
            effect = UIBlurEffect(style: Self.style(thickness))
        }
        // Interactive glass answers the touch, which rises to the layout.
        isUserInteractionEnabled = material.glass?.isInteractive == true
    }

    /// Lays `fill` over the backdrop across `bounds` and `stroke`'s outline `width` wide over both, along `outline`
    /// - nothing where they paint nothing.
    func lay(
        _ fill: UIKitBrush, stroke: UIKitBrush, width: Double, over bounds: CGRect, along outline: ContainerShape
    ) {
        if width > 0, let color = stroke.lineColor {
            let drawn = line ?? CAShapeLayer()
            if line == nil { contentView.layer.addSublayer(drawn) }
            drawn.frame = CGRect(origin: .zero, size: bounds.size)
            drawn.path = outline.path(in: drawn.frame.insetBy(dx: width / 2, dy: width / 2))
            drawn.lineWidth = width
            drawn.strokeColor = color.cgColor
            drawn.fillColor = nil
            line = drawn
        } else {
            line?.removeFromSuperlayer()
            line = nil
        }
        let painted = fill.layer(over: CGRect(origin: .zero, size: bounds.size), reusing: wash)
        if painted !== wash {
            wash?.removeFromSuperlayer()
            if let painted { contentView.layer.insertSublayer(painted, at: 0) }
        }
        wash = painted
    }
}
#endif
