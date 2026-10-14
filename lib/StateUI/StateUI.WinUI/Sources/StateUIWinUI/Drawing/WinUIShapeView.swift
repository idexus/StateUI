// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

@_spi(Host) import StateUI
@_spi(Host) import StateUIHost
import CStateUIWinUI

/// A shape filled and outlined: a layout's box, drawn behind its children.
/// Design: docs/design/platforms/winui/drawing.md#a-box-and-its-brush
@MainActor
final class WinUIShapeView: WinUIView {
    /// Whether the shape is an ellipse; a rectangle, rounded or not, is the other element.
    let isEllipse: Bool

    private var painted: (outline: ContainerShape, fill: WinUIBrush, stroke: WinUIBrush, width: Double)?

    init(ellipse: Bool) {
        isEllipse = ellipse
        super.init { _ in stateui_winui_shape_make(ellipse ? StateUIOutlineEllipse : StateUIOutlineRectangle) }
    }

    /// Paints the shape, written only where it differs from what was; its corners round as far as its size holds
    /// them, a capsule's by half its shorter side, at each size it takes.
    func paint(outline: ContainerShape, fill: WinUIBrush, stroke: WinUIBrush, width: Double) {
        if let painted, painted.outline == outline, painted.fill == fill, painted.stroke == stroke,
           painted.width == width { return }

        painted = (outline, fill, stroke, width)
        let rounds = outline != .rectangle && outline != .ellipse
        paint("shape", followsSize: fill.followsSize || stroke.followsSize || rounds) { [handle] size in
            let radius = outline.relay(width: size.width, height: size.height).radius
            fill.withRelayBrush(over: size) { fill in
                stroke.withRelayBrush(over: size) { stroke in
                    stateui_winui_shape_set(handle, radius, fill, stroke, width)
                }
            }
        }
    }
}
