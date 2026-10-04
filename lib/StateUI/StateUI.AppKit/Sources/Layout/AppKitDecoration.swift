// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a layout draws of its own box: its background and its outline on its shape, and - where it clips - the cut
/// of what it holds to that shape. A plain colour on a plain box is the layer's own, with nothing drawn.
/// Design: docs/design/platforms/appkit/views.md#a-layouts-own-box
@MainActor
final class AppKitDecoration {
    private var fill = AppKitBrush()
    private var stroke = AppKitBrush()
    private var lineWidth: CGFloat = 0
    private var shape = ContainerShape.rectangle
    private var clips = false

    /// Whether the box is drawn: an outline, a shape or a gradient; otherwise the layer paints its colour.
    var draws: Bool {
        lineWidth > 0 && stroke.lineColor != nil || shape != .rectangle || fill.isGradient
    }

    /// The colour the layer paints where nothing is drawn.
    var layerColor: CGColor? {
        draws ? nil : fill.color?.cgColor
    }

    /// Takes the element's values - its background a colour or a brush, its outline by the host layer's rule
    /// (`BoxArithmetic`); the view draws again.
    func apply(
        background: HostValue?, stroke: HostValue?, lineWidth: Double?, shape: HostValue?, clips: Bool,
        to view: NSView
    ) {
        fill = AppKitBrush(background)
        self.stroke = AppKitBrush(stroke)
        self.lineWidth = CGFloat(BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth))
        self.shape = BoxArithmetic.outline(shape)
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
        (clips ? shape : .rectangle).cut(layer)
    }

    /// Paints the background and strokes the outline on the shape within `bounds`.
    func draw(in bounds: NSRect) {
        let inset = lineWidth / 2
        let path = shape.path(in: bounds.insetBy(dx: inset, dy: inset))
        fill.draw(in: path, bounds: bounds)
        stroke.stroke(path, width: lineWidth)
    }
}

#endif
