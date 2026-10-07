// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A layout's backdrop: the platform's glass or material behind what it holds - no child of it, kept beneath its
/// children - its background laid over it, in its content.
/// Design: docs/design/platforms/uikit/drawing.md#a-layouts-backdrop
@MainActor
final class UIKitBackdropView: UIVisualEffectView {
    /// What it shows, as the host layer read it.
    private(set) var shown: HostBackdrop?

    /// The background laid over the backdrop, and the outline over both.
    private var wash: CALayer?
    private var line: CAShapeLayer?

    /// UIKit's material for a thickness: its own four.
    static func style(_ material: Material) -> UIBlurEffect.Style {
        switch material {
        case .ultraThin: .systemUltraThinMaterial
        case .thin: .systemThinMaterial
        case .regular: .systemMaterial
        case .thick: .systemThickMaterial
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

    /// Shows `backdrop` - glass where it asks for glass, else its material - where it changed.
    func show(_ backdrop: HostBackdrop) {
        guard backdrop != shown else { return }
        shown = backdrop
        if let glass = backdrop.glass {
            let effect = UIGlassEffect(style: glass.isClear ? .clear : .regular)
            effect.tintColor = glass.tint.flatMap(UIColor.init(stateUI:))
            effect.isInteractive = glass.isInteractive
            self.effect = effect
        } else {
            effect = UIBlurEffect(style: Self.style(backdrop.material))
        }
        // Interactive glass answers the touch, which rises to the layout.
        isUserInteractionEnabled = backdrop.glass?.isInteractive == true
    }

    /// Lays `fill` over the backdrop across `bounds` and `stroke`'s outline `width` wide over both, cut to `outline`
    /// - nothing where they paint nothing.
    func lay(
        _ fill: UIKitBrush, stroke: UIKitBrush, width: Double, over bounds: CGRect, cut outline: ContainerShape
    ) {
        frame = bounds
        let path = outline.path(in: CGRect(origin: .zero, size: bounds.size))
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
        switch outline {
        case .rectangle:
            layer.cornerRadius = 0
            layer.mask = nil
        case .roundedRectangle(let radius):
            layer.cornerRadius = min(radius, min(bounds.width, bounds.height) / 2)
            layer.cornerCurve = .continuous
            layer.mask = nil
        case .ellipse:
            layer.cornerRadius = 0
            let mask = layer.mask as? CAShapeLayer ?? CAShapeLayer()
            mask.frame = CGRect(origin: .zero, size: bounds.size)
            mask.path = path
            layer.mask = mask
        }
    }
}
#endif
