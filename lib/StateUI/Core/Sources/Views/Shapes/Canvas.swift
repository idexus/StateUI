// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Canvas`'s own properties, shared by the control and its `Style<Canvas>`.
public protocol CanvasProperties: PropertyContainer {}

extension CanvasProperties {
    /// What to draw, written as the canvas calls that make the drawing.
    ///
    ///     .drawing {
    ///         Draw.strokeColor(.firebrick)
    ///         Draw.lineWidth(2)
    ///         Draw.strokeLine(x1: 0, y1: 0, x2: 120, y2: 0)
    ///     }
    ///
    /// Usually given in the initializer instead; this is how a `Style<Canvas>`
    /// states one.
    public func drawing(@DrawingBuilder _ drawing: () -> [DrawCommand]) -> Modified {
        setValue(CanvasContract.drawing, drawing())
    }
}

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
public struct Canvas: ElementView, CanvasProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty canvas - what a `Style<Canvas>` is written against.
    public init() {
        node = Node(contract: CanvasContract.self)
    }

    /// A canvas showing what the closure draws.
    public init(@DrawingBuilder drawing: () -> [DrawCommand]) {
        node = Node(contract: CanvasContract.self)
        node.write(CanvasContract.drawing, drawing())
    }
}
