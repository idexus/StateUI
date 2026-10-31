// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

#if os(iOS)
import UIKit
@_spi(Host) import StateUI
@_spi(Host) import StateUIHost

/// The outline the tree gives a field - its color and width - and the shape its ground and outline follow, drawn on the
/// field's own layer in place of its frame; the field's own frame where the tree gives neither.
/// Design: docs/design/platforms/uikit/controls.md#a-fields-outline
@MainActor
final class UIKitFieldOutline {
    private var stroke: HostValue?
    private var width = 0.0
    private var shape: ContainerShape?

    /// The frame a field on one line drew of its own before the tree outlined it, given back where it no longer does.
    private var ownBorder: UITextField.BorderStyle?

    /// Whether the tree outlines or shapes the field, its own frame stepping aside.
    var isDrawn: Bool { stroke != nil || shape != nil }

    /// Takes what the tree says of the outline, by the host layer's reading of it (`BoxArithmetic`).
    func set(stroke: HostValue?, lineWidth: Double?, shape: HostValue?) {
        self.stroke = stroke
        width = BoxArithmetic.outlineWidth(stroke: stroke, width: lineWidth)
        self.shape = shape.map(BoxArithmetic.outline)
    }

    /// Draws it on `field` at its size - a capsule's ends follow it - its corners `ownRadius` where the tree says no
    /// shape.
    func draw(on field: UIView, ownRadius: CGFloat) {
        let size = field.bounds.size
        field.layer.borderWidth = width
        field.layer.borderColor = HostBrush(stroke).firstColor.flatMap(UIColor.init(stateUI:))?.cgColor
        field.layer.cornerRadius = shape.map {
            BoxArithmetic.cornerRadius(of: $0, width: size.width, height: size.height)
        } ?? ownRadius
        field.layer.cornerCurve = .continuous
        field.clipsToBounds = field.layer.cornerRadius > 0
        guard let line = field as? UITextField else { return }
        if isDrawn, line.borderStyle != .none {
            ownBorder = line.borderStyle
            line.borderStyle = .none
        } else if !isDrawn, let own = ownBorder {
            line.borderStyle = own
            ownBorder = nil
        }
    }
}
#endif
