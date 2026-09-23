// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Canvas`'s own properties, shared by the control and its `Style<Canvas>`.
public protocol CanvasProperties: PropertyContainer {}

extension CanvasProperties {
    /// What to draw, written as the canvas calls that make the drawing.
    ///
    ///     .drawable {
    ///         Draw.strokeColor(.firebrick)
    ///         Draw.strokeWidth(2)
    ///         Draw.drawLine(x1: 0, y1: 0, x2: 120, y2: 0)
    ///     }
    ///
    /// Usually given in the initializer instead; this is how a `Style<Canvas>`
    /// states one.
    public func drawable(@DrawingBuilder _ drawing: () -> [DrawCommand]) -> Modified {
        setValue(CanvasContract.drawable, drawing())
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
///         Draw.drawText(
///             "Drawn, not built",
///             x: 0, y: 0, width: 160, height: 48,
///             horizontalAlignment: .center, verticalAlignment: .center)
///     }
///     .height(48)
///
/// The drawing travels as data - the canvas calls `Draw` offers, in order -
/// and the host replays them on the platform's own canvas. A drawing that
/// reads a state is drawn again when the state changes.
public struct Canvas: View, CanvasProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty canvas - what a `Style<Canvas>` is written against.
    public init() {
        node = Node(contract: CanvasContract.self)
    }

    /// A canvas showing what the closure draws.
    public init(@DrawingBuilder _ drawing: () -> [DrawCommand]) {
        node = Node(contract: CanvasContract.self)
        node.write(CanvasContract.drawable, drawing())
    }

    /// A finger went down, or a mouse button was pressed.
    ///
    /// The point is in the canvas's own coordinates - the same ones the drawing
    /// instructions use, so what arrives can be drawn where it happened.
    public func onPressed(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        onEvent(CanvasContract.pressed, handler)
    }

    /// It moved while still down, with where it is now - the canvas's own
    /// coordinates again.
    public func onDragged(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        onEvent(CanvasContract.dragged, handler)
    }

    /// It was lifted, with where it left off.
    public func onReleased(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        onEvent(CanvasContract.released, handler)
    }
}
