// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit

/// An oval button's face, the configuration's background view: its fill and outline drawn on the oval the button's
/// size holds, which a configuration's corners cannot draw.
@MainActor
final class UIKitOvalFace: UIView {
    override static var layerClass: AnyClass { CAShapeLayer.self }

    private var shape: CAShapeLayer { layer as! CAShapeLayer }

    init(fill: UIColor?, stroke: UIColor?, width: Double) {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        shape.fillColor = fill?.cgColor
        shape.strokeColor = stroke?.cgColor
        shape.lineWidth = stroke == nil ? 0 : width
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("UIKitOvalFace is made in code")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let inset = shape.lineWidth / 2
        shape.path = CGPath(ellipseIn: bounds.insetBy(dx: inset, dy: inset), transform: nil)
    }
}

#endif
