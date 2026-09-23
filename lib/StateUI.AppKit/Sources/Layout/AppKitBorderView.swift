// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI

/// A border that clips its background, its outline and what it holds to the
/// requested shape.
@MainActor
final class AppKitBorderView: AppKitSingleChildView {
    private var fill = AppKitBrush()
    private var stroke = AppKitBrush()
    private var strokeWidth: CGFloat = 1
    private var shape = AppKitBorderShape.rectangle

    func apply(
        backgroundColor: NSColor?,
        background: HostValue?,
        stroke: HostValue?,
        strokeWidth: Double?,
        shape: HostValue?
    ) {
        fill = AppKitBrush(background) ?? AppKitBrush(color: backgroundColor)
        self.stroke = AppKitBrush(stroke) ?? AppKitBrush()
        self.strokeWidth = max(0, strokeWidth ?? 1)
        self.shape = AppKitBorderShape(shape)
        clipToShape()
        needsDisplay = true
    }

    override func layout() {
        super.layout()
        clipToShape()
    }

    /// What the border holds is cut to its shape - a picture in a rounded card
    /// has rounded corners - on the border's own layer, so the compositor clips
    /// the views inside as well as the border's own drawing.
    private func clipToShape() {
        wantsLayer = true
        clipsToBounds = true
        guard let layer else { return }

        switch shape {
        case .rectangle:
            layer.cornerRadius = 0
            layer.mask = nil
        case .rounded(let radius):
            layer.cornerRadius = min(radius, min(bounds.width, bounds.height) / 2)
            layer.mask = nil
        case .ellipse:
            layer.cornerRadius = 0
            let mask = layer.mask as? CAShapeLayer ?? CAShapeLayer()
            mask.frame = layer.bounds
            mask.path = CGPath(ellipseIn: layer.bounds, transform: nil)
            layer.mask = mask
        }
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        let inset = strokeWidth / 2
        let path = shape.path(in: bounds.insetBy(dx: inset, dy: inset))
        fill.draw(in: path, bounds: bounds)

        guard strokeWidth > 0 else { return }
        stroke.stroke(path, width: strokeWidth)
    }
}

private enum AppKitBorderShape {
    case rectangle
    case rounded(CGFloat)
    case ellipse

    init(_ value: HostValue?) {
        guard let parts = value?.values, let kind = parts.first?.enumeration else {
            self = .rectangle
            return
        }

        switch kind {
        case 1: self = .rounded(max(0, parts.value(1)?.number ?? 0))
        case 2: self = .ellipse
        default: self = .rectangle
        }
    }

    func path(in rect: NSRect) -> NSBezierPath {
        switch self {
        case .rectangle: return NSBezierPath(rect: rect)
        case .rounded(let radius):
            return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
        case .ellipse: return NSBezierPath(ovalIn: rect)
        }
    }
}

#endif
