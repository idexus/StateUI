// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import QuartzCore
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// How a view is drawn over its place: its own transform, then a placing layout's, as one matrix on its layer, and
/// its own opacity times the one it is placed with.
/// Design: docs/design/platforms/uikit/drawing.md#drawn-over-its-place
@MainActor
final class UIKitViewDrawing {
    /// The element's own move, turn and scale.
    var own = HostDrawingTransform.identity {
        didSet { if own != oldValue { compose() } }
    }

    /// How a placing layout draws the view over the place it gave; nil for none.
    var placement: HostDrawingTransform? {
        didSet { if placement != oldValue { compose() } }
    }

    /// The element's own opacity, and the one a placing layout draws it with.
    var ownOpacity = 1.0 {
        didSet { if ownOpacity != oldValue { compose() } }
    }

    var placedOpacity = 1.0 {
        didSet { if placedOpacity != oldValue { compose() } }
    }

    /// How opaque the view stands, as the element says.
    var opacity: Double { ownOpacity }

    private(set) weak var view: UIView?

    init(_ view: UIView) {
        self.view = view
    }

    /// Puts the matrix and the opacity on the view for its size: StateUI's matrix turns about the view's top left,
    /// and a layer turns about its middle, so the matrix is carried there.
    func compose() {
        guard let view else { return }
        let transform = composed(for: view.bounds.size)
        if !CATransform3DEqualToTransform(view.layer.transform, transform) { view.layer.transform = transform }

        let alpha = CGFloat(ownOpacity * placedOpacity)
        if view.alpha != alpha { view.alpha = alpha }
    }

    /// The layer's transform for a view of `size`.
    private func composed(for size: CGSize) -> CATransform3D {
        var matrix = own.matrix(width: size.width, height: size.height)
        if let placement { matrix = matrix * placement.matrix(width: size.width, height: size.height) }

        var middleToCorner = HostMatrix.identity
        (middleToCorner.m41, middleToCorner.m42) = (size.width / 2, size.height / 2)
        var cornerToMiddle = HostMatrix.identity
        (cornerToMiddle.m41, cornerToMiddle.m42) = (-size.width / 2, -size.height / 2)
        return CATransform3D(middleToCorner * matrix * cornerToMiddle)
    }

    /// The transform the view is drawn with, where its layer holds it now; nil where the layer holds another.
    var heldTransformForTesting: HostDrawingTransform? {
        guard let view else { return own }
        return CATransform3DEqualToTransform(view.layer.transform, composed(for: view.bounds.size)) ? own : nil
    }
}

extension CATransform3D {
    /// The same matrix, in Core Animation's terms: both carry a point as a row.
    init(_ matrix: HostMatrix) {
        self.init(
            m11: matrix.m11, m12: matrix.m12, m13: matrix.m13, m14: matrix.m14,
            m21: matrix.m21, m22: matrix.m22, m23: matrix.m23, m24: matrix.m24,
            m31: matrix.m31, m32: matrix.m32, m33: matrix.m33, m34: matrix.m34,
            m41: matrix.m41, m42: matrix.m42, m43: matrix.m43, m44: matrix.m44)
    }
}
#endif
