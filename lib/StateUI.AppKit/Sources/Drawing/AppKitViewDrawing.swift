// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(macOS)
import AppKit
@_spi(Host) import StateUI

/// How StateUI draws one view over the frame AppKit gives it.
///
/// AppKit owns a layer-backed view's layer - its class, its drawing and its
/// geometry: whenever the view's frame or alpha moves, AppKit writes the
/// layer's transform and opacity from its own state. StateUI owns how the
/// view is drawn over that frame: the drawing transform of the view's own
/// properties, and the drawing a placing layout gives it. This object
/// observes each of AppKit's writes and composes StateUI's parts over it, so
/// a frame change, a placement and a property each keep their own part.
/// While there is nothing to compose, it observes nothing and the layer is
/// exactly as AppKit wrote it.
@MainActor
final class AppKitViewDrawing {
    /// How the view's own properties move, turn and size it.
    var own = HostDrawingTransform.identity {
        didSet { if own != oldValue { refresh() } }
    }

    /// How a placing layout draws the view over the rectangle it placed,
    /// after the view's own drawing.
    var placement: HostDrawingTransform? {
        didSet { if placement != oldValue { refresh() } }
    }

    /// The opacity a placing layout draws the view with, over its own.
    var placedOpacity = 1.0 {
        didSet { if placedOpacity != oldValue { refresh() } }
    }

    private weak var view: NSView?
    private weak var layer: CALayer?
    private var geometry = CATransform3DIdentity
    private var alpha: Float = 1
    private var writing = false
    private var observations: [NSKeyValueObservation] = []

    init(_ view: NSView) {
        self.view = view
    }

    private var composes: Bool {
        !own.isIdentity || placement.map { !$0.isIdentity } == true || placedOpacity != 1
    }

    private func refresh() {
        guard let view else { return }
        guard composes else {
            release()
            return
        }

        view.wantsLayer = true
        guard let layer = view.layer else { return }
        if layer !== self.layer { observe(layer) }
        compose()
    }

    /// Hands the layer back exactly as AppKit last wrote it.
    private func release() {
        guard let layer else { return }
        observations = []
        self.layer = nil
        write {
            layer.transform = geometry
            layer.opacity = alpha
        }
    }

    private func observe(_ layer: CALayer) {
        release()
        self.layer = layer
        geometry = layer.transform
        alpha = layer.opacity
        observations = [
            layer.observe(\.transform) { [weak self] layer, _ in
                let transform = layer.transform
                MainActor.assumeIsolated { self?.appKitWrote(transform: transform) }
            },
            layer.observe(\.opacity) { [weak self] layer, _ in
                let opacity = layer.opacity
                MainActor.assumeIsolated { self?.appKitWrote(opacity: opacity) }
            },
            layer.observe(\.bounds) { [weak self] _, _ in
                MainActor.assumeIsolated { self?.compose() }
            },
        ]
    }

    private func appKitWrote(transform: CATransform3D) {
        guard !writing else { return }
        geometry = transform
        compose()
    }

    private func appKitWrote(opacity: Float) {
        guard !writing else { return }
        alpha = opacity
        compose()
    }

    private func compose() {
        guard let layer, let view else { return }

        let width = Double(layer.bounds.width)
        let height = Double(layer.bounds.height)
        var matrix = own.matrix(width: width, height: height)
        if let placement {
            matrix = matrix * placement.matrix(width: width, height: height)
        }

        // A layer's transform acts in its superview's space. StateUI's
        // drawing counts y downward; under an unflipped superview the matrix
        // is carried there through a vertical flip of the view's own height.
        if view.superview?.isFlipped == false {
            var flip = HostMatrix.identity
            flip.m22 = -1
            flip.m42 = height
            matrix = flip * matrix * flip
        }

        let transform = CATransform3DConcat(CATransform3D(matrix), geometry)
        let opacity = alpha * Float(placedOpacity)
        write {
            if !CATransform3DEqualToTransform(layer.transform, transform) {
                layer.transform = transform
            }
            if layer.opacity != opacity { layer.opacity = opacity }
        }
    }

    private func write(_ change: () -> Void) {
        writing = true
        change()
        writing = false
    }
}

extension CATransform3D {
    /// The same matrix: both act on row vectors, entry for entry.
    init(_ matrix: HostMatrix) {
        self.init(
            m11: matrix.m11, m12: matrix.m12, m13: matrix.m13, m14: matrix.m14,
            m21: matrix.m21, m22: matrix.m22, m23: matrix.m23, m24: matrix.m24,
            m31: matrix.m31, m32: matrix.m32, m33: matrix.m33, m34: matrix.m34,
            m41: matrix.m41, m42: matrix.m42, m43: matrix.m43, m44: matrix.m44)
    }
}
#endif
