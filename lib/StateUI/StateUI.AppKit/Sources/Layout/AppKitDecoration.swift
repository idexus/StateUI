// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
import QuartzCore
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// What a layout draws of its own box: its background - a colour or a gradient, or a blur or glass with its tint -
/// and its outline on its shape, and - where it clips - the cut of what it holds to that shape. A plain colour on a
/// plain box is the layer's own, with nothing drawn.
/// Design: docs/design/platforms/appkit/views.md#a-layouts-own-box
@MainActor
final class AppKitDecoration {
    private var fill = AppKitBrush()
    private var stroke = AppKitBrush()
    private var lineWidth: CGFloat = 0
    private var shape = ContainerShape.rectangle
    private var clips = false
    private var material = HostMaterial(nil)

    /// The blur or glass the box shows behind what it holds, where its background is one.
    private(set) var surface: (any AppKitBoxSurface)?

    /// Whether the view draws the box: an outline, a shape or a gradient with no blur or glass; otherwise the layer
    /// paints its colour, or the blur's or glass's surface the box.
    var draws: Bool {
        surface == nil && (lineWidth > 0 && stroke.lineColor != nil || shape != .rectangle || fill.isGradient)
    }

    /// The colour the layer paints where nothing is drawn.
    var layerColor: CGColor? {
        draws || surface != nil ? nil : fill.color?.cgColor
    }

    /// Takes the element's values - its background by the host layer's reading of it (`HostMaterial`), its outline
    /// by the host layer's rule (`BoxArithmetic`); the view draws again.
    func apply(
        background: HostValue?, stroke: HostValue?, lineWidth: Double?, shape: HostValue?, clips: Bool,
        to view: NSView
    ) {
        material = HostMaterial(background)
        fill = AppKitBrush(material.paint)
        self.stroke = AppKitBrush(stroke)
        self.lineWidth = CGFloat(BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth))
        self.shape = BoxArithmetic.outline(shape)
        self.clips = clips
        clip(view)
        view.layer?.backgroundColor = layerColor
        showSurface(in: view)
        view.needsDisplay = true
    }

    /// Lays the background's glass - in its tint - or its blur - its tint over it - under what the view holds,
    /// cut to its shape and edged with its outline, which the view's own drawing, under it, could not show; takes
    /// it away where the background is neither.
    private func showSurface(in view: NSView) {
        if let glass = material.glass {
            let shown = surface as? AppKitGlassView ?? place(AppKitGlassView(), in: view)
            shown.show(glass, tint: material.paint.flatMap(nsColor))
        } else if let thickness = material.blur {
            let shown = surface as? AppKitMaterialView ?? place(AppKitMaterialView(thickness, behindWindow: false), in: view)
            shown.material = AppKitMaterialView.role(thickness)
            shown.wash.fill = fill
        } else {
            surface?.removeFromSuperview()
            surface = nil
            return
        }
        shapeSurface(in: view)
    }

    /// Lays `made` under what the view holds, in place of the surface it held.
    private func place<Surface: AppKitBoxSurface>(_ made: Surface, in view: NSView) -> Surface {
        surface?.removeFromSuperview()
        made.autoresizingMask = [.width, .height]
        made.wantsLayer = true
        view.addSubview(made, positioned: .below, relativeTo: nil)
        surface = made
        return made
    }

    /// Fits the surface to the box: its bounds, its shape and its outline.
    private func shapeSurface(in view: NSView) {
        guard let surface else { return }
        surface.frame = view.bounds
        if let glass = surface as? AppKitGlassView {
            glass.cornerRadius = shape.cornerRadius(in: view.bounds)
        }
        guard let layer = surface.layer else { return }
        layer.masksToBounds = true
        shape.cut(layer)
        layer.borderWidth = lineWidth
        layer.borderColor = lineWidth > 0 ? stroke.lineColor?.cgColor : nil
    }

    /// Cuts what the view holds to its shape where it clips - on its own layer, so the compositor clips the
    /// views inside as well as its drawing - and nothing where it does not.
    func clip(_ view: NSView) {
        view.wantsLayer = true
        view.clipsToBounds = clips
        shapeSurface(in: view)
        guard let layer = view.layer else { return }
        (clips ? shape : .rectangle).cut(layer)
    }

    /// Paints the background and strokes the outline on the shape within `bounds` - a backdrop's surface does
    /// both itself.
    func draw(in bounds: NSRect) {
        guard surface == nil else { return }
        let inset = lineWidth / 2
        let path = shape.path(in: bounds.insetBy(dx: inset, dy: inset))
        fill.draw(in: path, bounds: bounds)
        stroke.stroke(path, width: lineWidth)
    }
}

#endif
