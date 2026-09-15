// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Canvas's own properties - the half a `Style<Canvas>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
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
    /// This is how a `Style<Canvas>` states a drawing. One view's own
    /// usually goes in its initializer instead, which takes the same closure -
    /// the drawing being what gives that view its purpose.
    public func drawable(@DrawingBuilder _ drawing: () -> [DrawCommand]) -> Modified {
        setValue(.drawable, Canvas.value(drawing()))
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
/// The drawing travels as DATA - its canvas calls, in order - because an
/// object with a draw method is the one thing this boundary cannot carry; the
/// host replays the calls against the platform's own canvas. Everything `Draw`
/// offers is one such call - see Types/Drawing.swift.
///
/// The instructions are run again whenever the view is described again -
/// which a state the drawing reads is enough to cause - so a drawing follows
/// state: change what the closure produces and the view is redrawn.
public struct Canvas: View, CanvasProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty canvas - what a `Style<Canvas>` is written against.
    public init() {
        node = Node(type: .canvas)
    }

    /// A canvas showing what the closure draws.
    public init(@DrawingBuilder _ drawing: () -> [DrawCommand]) {
        node = Node(type: .canvas, props: [.drawable: Self.value(drawing())])
    }

    /// A finger went down, or a mouse button was pressed.
    ///
    /// The point is in the canvas's own coordinates - the same ones the drawing
    /// instructions use, so what arrives can be drawn where it happened.
    public func onPressed(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        point(.pressed, handler)
    }

    /// It moved while still down, with where it is now - the canvas's own
    /// coordinates again.
    public func onDragged(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        point(.dragged, handler)
    }

    /// It was lifted, with where it left off.
    public func onReleased(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        point(.released, handler)
    }

    private func point(_ event: Event, _ handler: @escaping ValueEventHandler<Point>) -> Self {
        addHandler(event) {
            // A payload that will not parse leaves the handler alone, the way a
            // gesture's does: half a point is worse than none.
            if let point = EventBuffer.current.value().flatMap(Point.init(propValue:)) {
                try await handler(point)
            }
        }
    }

    /// The drawing as one value: a list of records, each of them the list of
    /// values one canvas call is - see Types/Drawing.swift.
    fileprivate static func value(_ commands: [DrawCommand]) -> PropValue {
        .values(commands.map { $0.propValue })
    }
}
