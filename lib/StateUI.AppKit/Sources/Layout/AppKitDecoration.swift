// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI

/// What a layout draws of its own box: its background and its outline on its shape, and - where it clips - the cut
/// of what it holds to that shape. A plain colour on a plain box is the layer's own, with nothing drawn.
/// Design: docs/design/platforms/appkit/views.md#a-layouts-own-box
@MainActor
final class AppKitDecoration {
    private var fill = AppKitBrush()
    private var stroke = AppKitBrush()
    private var strokeWidth: CGFloat = 1
    private var shape = Shape.rectangle
    private var clips = false

    /// Whether the box is drawn: an outline, a shape or a gradient; otherwise the layer paints its colour.
    var draws: Bool {
        if case .solid = stroke.kind { return true }
        if case .rectangle = shape {} else { return true }
        switch fill.kind {
        case .none, .solid: return false
        case .linear, .radial: return true
        }
    }

    /// The colour the layer paints where nothing is drawn.
    var layerColor: CGColor? {
        guard !draws, case .solid(let color) = fill.kind else { return nil }
        return color.cgColor
    }

    /// Takes the element's values; the view draws again.
    func apply(
        backgroundColor: NSColor?, background: HostValue?, stroke: HostValue?, strokeWidth: Double?,
        shape: HostValue?, clips: Bool, to view: NSView
    ) {
        fill = AppKitBrush(background) ?? AppKitBrush(color: backgroundColor)
        self.stroke = AppKitBrush(stroke) ?? AppKitBrush()
        self.strokeWidth = max(0, strokeWidth ?? 1)
        self.shape = Shape(shape)
        self.clips = clips
        clip(view)
        view.layer?.backgroundColor = layerColor
        view.needsDisplay = true
    }

    /// Cuts what the view holds to its shape where it clips - on its own layer, so the compositor clips the
    /// views inside as well as its drawing - and nothing where it does not.
    func clip(_ view: NSView) {
        view.wantsLayer = true
        view.clipsToBounds = clips
        guard let layer = view.layer else { return }

        switch (clips, shape) {
        case (true, .rounded(let radius)):
            layer.cornerRadius = min(radius, min(view.bounds.width, view.bounds.height) / 2)
            layer.mask = nil
        case (true, .ellipse):
            layer.cornerRadius = 0
            let mask = layer.mask as? CAShapeLayer ?? CAShapeLayer()
            mask.frame = layer.bounds
            mask.path = CGPath(ellipseIn: layer.bounds, transform: nil)
            layer.mask = mask
        default:
            layer.cornerRadius = 0
            layer.mask = nil
        }
    }

    /// Paints the background and strokes the outline on the shape within `bounds`.
    func draw(in bounds: NSRect) {
        let inset = strokeWidth / 2
        let path = shape.path(in: bounds.insetBy(dx: inset, dy: inset))
        fill.draw(in: path, bounds: bounds)

        guard strokeWidth > 0 else { return }
        stroke.stroke(path, width: strokeWidth)
    }

    /// The shape a value names: a rectangle, a rounded one, or an oval.
    enum Shape {
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
            case .rounded(let radius): return NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius)
            case .ellipse: return NSBezierPath(ovalIn: rect)
            }
        }
    }
}

#endif
