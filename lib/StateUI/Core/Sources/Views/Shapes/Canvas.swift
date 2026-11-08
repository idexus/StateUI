// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A canvas to draw on, one instruction at a time.
///
///     Canvas {
///         Draw.fillColor(.cornflowerBlue)
///         Draw.fillRoundedRectangle(x: 0, y: 0, width: 160, height: 48, cornerRadius: 8)
///
///         Draw.textColor(.white)
///         Draw.fontSize(15)
///         Draw.text(
///             "Drawn, not built",
///             x: 0, y: 0, width: 160, height: 48,
///             horizontalAlignment: .center, verticalAlignment: .center)
///     }
///     .height(48)
///
/// The drawing travels as data - the canvas calls `Draw` offers, in order -
/// and the host replays them on the platform's own canvas. A drawing that
/// reads a state is drawn again when the state changes. A canvas hears a
/// press as every view does, in its own points - the ones the drawing uses:
///
///     Canvas { strokes(trail) }
///         .onPointerPressed { point in trail = [point] }
///         .onPanUpdated { pan in trail.append(pan.at) }
public struct Canvas: ElementView {
    /// The node this control describes.
    public var node: Node

    /// A canvas showing what the closure draws.
    public init(@DrawingBuilder drawing: () -> [DrawCommand]) {
        node = Node(contract: CanvasContract.self)
        node.write(CanvasContract.drawing, drawing())
    }
}
