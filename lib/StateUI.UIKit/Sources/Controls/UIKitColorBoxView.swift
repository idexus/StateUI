// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// A ColorBox: one colour filling the room its layout gives it, which asks for none, its corners rounded as the tree
/// says (`BoxArithmetic`).
@MainActor
final class UIKitColorBoxView: UIView {
    /// The corners' radii clockwise from the top left.
    private var radii = [0.0, 0.0, 0.0, 0.0]

    override class var layerClass: AnyClass { CAShapeLayer.self }

    private var shape: CAShapeLayer { layer as! CAShapeLayer }

    init() {
        super.init(frame: .zero)
        backgroundColor = nil
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitColorBoxView is made in code")
    }

    /// The box's colour, and the radii of its corners - one for all four, or four in StateUI's order: top left,
    /// top right, bottom left, bottom right; nil draws no colour.
    func apply(color: HostValue?, corners: HostValue?) {
        radii = BoxArithmetic.clockwise(corners.flatMap(CornerRadius.init(propValue:)))
        shape.fillColor = color.flatMap(UIColor.init(stateUI:))?.cgColor
        setNeedsLayout()
    }

    override func sizeThatFits(_ size: CGSize) -> CGSize {
        .zero
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let corners = radii.map { radius in
            let fitted = BoxArithmetic.fitted(radius, width: bounds.width, height: bounds.height)
            return CGSize(width: fitted.width, height: fitted.height)
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        shape.path = .rounded(bounds, corners: corners)
        CATransaction.commit()
    }
}
#endif
