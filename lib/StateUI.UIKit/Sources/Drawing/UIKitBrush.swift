// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A fill UIKit paints: the host layer's reading of it (`HostBrush`), its colours in sRGB, as the layer that paints
/// it.
/// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
struct UIKitBrush: Equatable {
    /// What the tree's value describes.
    let brush: HostBrush

    /// The brush the tree's `value` describes: a colour, a gradient, or nothing.
    init(_ value: HostValue? = nil) {
        brush = HostBrush(value)
    }

    /// Whether it paints nothing.
    var isEmpty: Bool {
        brush == .none
    }

    /// The colour a line draws with: its colour, or its first stop's.
    var lineColor: UIColor? {
        brush.firstColor.flatMap(UIColor.init(stateUI:))
    }

    /// A layer painting the brush over `bounds`, made anew or `reusing` one of the kind it needs: a gradient's
    /// points are fractions of `bounds`, a radial one a circle reaching as `HostBrush.reach` says.
    func layer(over bounds: CGRect, reusing layer: CALayer?) -> CALayer? {
        switch brush {
        case .none:
            return nil
        case .solid(let value):
            let painted = layer.flatMap { $0 is CAGradientLayer ? nil : $0 } ?? CALayer()
            painted.backgroundColor = UIColor(stateUI: value)?.cgColor
            painted.frame = bounds
            return painted
        case .linear(let from, let to, let stops):
            let gradient = layer as? CAGradientLayer ?? CAGradientLayer()
            gradient.type = .axial
            Self.paint(gradient, stops)
            gradient.startPoint = CGPoint(x: from.x, y: from.y)
            gradient.endPoint = CGPoint(x: to.x, y: to.y)
            gradient.frame = bounds
            return gradient
        case .radial(let center, let radius, let stops):
            let gradient = layer as? CAGradientLayer ?? CAGradientLayer()
            gradient.type = .radial
            Self.paint(gradient, stops)
            let reach = HostBrush.reach(of: radius, width: bounds.width, height: bounds.height)
            gradient.startPoint = CGPoint(x: center.x, y: center.y)
            gradient.endPoint = CGPoint(
                x: center.x + (bounds.width > 0 ? reach / bounds.width : 0),
                y: center.y + (bounds.height > 0 ? reach / bounds.height : 0))
            gradient.frame = bounds
            return gradient
        }
    }

    private static func paint(_ gradient: CAGradientLayer, _ stops: [HostBrush.Stop]) {
        gradient.colors = stops.compactMap { UIColor(stateUI: $0.color)?.cgColor }
        gradient.locations = stops.map { NSNumber(value: $0.offset) }
    }
}
#endif
