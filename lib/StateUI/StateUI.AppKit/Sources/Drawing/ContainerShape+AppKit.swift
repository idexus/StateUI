// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A box's outline in AppKit's terms - the host layer's (`BoxArithmetic`): its path, and the cut of a layer to it.
/// Design: docs/design/host/layout.md#a-box
extension ContainerShape {
    /// The outline within `rect`, its corners rounded as far as the room holds them.
    func path(in rect: NSRect) -> NSBezierPath {
        if self == .ellipse { return NSBezierPath(ovalIn: rect) }
        let radius = cornerRadius(in: rect)
        return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
    }

    /// The radius of the outline's corners within `rect` (`BoxArithmetic.cornerRadius`).
    func cornerRadius(in rect: NSRect) -> CGFloat {
        BoxArithmetic.cornerRadius(of: self, width: rect.width, height: rect.height)
    }

    /// Cuts `layer` to the outline: its corners where they round, a mask where it is an oval.
    func cut(_ layer: CALayer) {
        let bounds = layer.bounds
        guard self == .ellipse else {
            layer.cornerRadius = cornerRadius(in: bounds)
            layer.mask = nil
            return
        }
        layer.cornerRadius = 0
        let mask = layer.mask as? CAShapeLayer ?? CAShapeLayer()
        mask.frame = bounds
        mask.path = CGPath(ellipseIn: bounds, transform: nil)
        layer.mask = mask
    }

    /// Rounds `layer`'s corners along the outline - an oval as a capsule, which is what a layer's corners draw.
    func round(_ layer: CALayer) {
        layer.cornerRadius = cornerRadius(in: layer.bounds)
    }
}

#endif
