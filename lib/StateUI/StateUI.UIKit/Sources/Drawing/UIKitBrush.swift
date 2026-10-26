// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A fill UIKit paints: the host layer's reading of it (`HostBrush`), its colors in sRGB, as the layer that paints
/// it.
/// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
struct UIKitBrush: Equatable {
    /// What the tree's value describes.
    let brush: HostBrush

    /// The brush the tree's `value` describes: a color, a gradient, or nothing.
    init(_ value: HostValue? = nil) {
        brush = HostBrush(value)
    }

    /// Whether it paints nothing.
    var isEmpty: Bool {
        brush == .none
    }

    /// The brush drawn as a picture `size` points across - what UIKit takes for a bar's background - its colors in
    /// sRGB, as StateUI's are; nil for no size or nothing painted.
    func image(size: CGSize) -> UIImage? {
        guard size.width > 0, size.height > 0, brush != .none, let sRGB = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }
        func gradient(_ stops: [HostBrush.Stop]) -> CGGradient? {
            let colors = stops.compactMap { UIColor(stateUI: $0.color)?.cgColor }
            return CGGradient(colorsSpace: sRGB, colors: colors as CFArray, locations: stops.map { CGFloat($0.offset) })
        }
        let format = UIGraphicsImageRendererFormat.preferred()
        format.preferredRange = .standard
        let beyond: CGGradientDrawingOptions = [.drawsBeforeStartLocation, .drawsAfterEndLocation]
        return UIGraphicsImageRenderer(size: size, format: format).image { drawn in
            let context = drawn.cgContext
            switch brush {
            case .none:
                break
            case .solid(let value):
                context.setFillColor(UIColor(stateUI: value)?.cgColor ?? UIColor.clear.cgColor)
                context.fill(CGRect(origin: .zero, size: size))
            case .linear(let from, let to, let stops):
                guard let gradient = gradient(stops) else { return }
                context.drawLinearGradient(
                    gradient, start: CGPoint(x: from.x * size.width, y: from.y * size.height),
                    end: CGPoint(x: to.x * size.width, y: to.y * size.height), options: beyond)
            case .radial(let center, let radius, let stops):
                guard let gradient = gradient(stops) else { return }
                let middle = CGPoint(x: center.x * size.width, y: center.y * size.height)
                let reach = HostBrush.reach(of: radius, width: size.width, height: size.height)
                context.drawRadialGradient(
                    gradient, startCenter: middle, startRadius: 0, endCenter: middle, endRadius: reach,
                    options: beyond)
            }
        }
    }

    /// The color a line draws with: its color, or its first stop's.
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
