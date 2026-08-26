// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: GraphicsView.

/// GraphicsView's own properties - the half a `Style<GraphicsView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol GraphicsViewProperties: PropertyContainer {}

extension GraphicsViewProperties {
    /// What to draw, written as the calls a MAUI `IDrawable` would have made.
    /// MAUI: GraphicsView.Drawable.
    ///
    ///     .drawable {
    ///         Draw.strokeColor(.firebrick)
    ///         Draw.strokeSize(2)
    ///         Draw.drawLine(x1: 0, y1: 0, x2: 120, y2: 0)
    ///     }
    ///
    /// This is how a `Style<GraphicsView>` states a drawing. One view's own
    /// usually goes in its initializer instead, which takes the same closure -
    /// the drawing being what gives that view its purpose.
    public func drawable(@DrawingBuilder _ drawing: () -> [DrawCommand]) -> Modified {
        setValue(.drawable, GraphicsView.value(drawing()))
    }
}

/// A canvas to draw on, one instruction at a time.
///
///     GraphicsView {
///         Draw.fillColor(.cornflowerBlue)
///         Draw.fillRoundedRectangle(x: 0, y: 0, width: 160, height: 48, cornerRadius: 8)
///
///         Draw.fontColor(.white)
///         Draw.fontSize(15)
///         Draw.drawString(
///             "Drawn, not built",
///             x: 0, y: 0, width: 160, height: 48,
///             horizontalAlignment: .center, verticalAlignment: .center)
///     }
///     .heightRequest(48)
///
/// MAUI's GraphicsView takes an `IDrawable` - an object with a Draw method, and
/// an object is the one thing this boundary cannot carry. So the drawing travels
/// as the calls that method would have made, and the host replays them against
/// the real canvas. Everything `Draw` offers is a member of MAUI's own ICanvas.
///
/// The instructions are read again on every render, which is what makes a
/// drawing follow state: change what the closure produces and the view is
/// redrawn.
public struct GraphicsView: View, GraphicsViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty canvas - what a `Style<GraphicsView>` is written against.
    public init() {
        node = Node(type: .graphicsView)
    }

    /// A canvas showing what the closure draws.
    public init(@DrawingBuilder _ drawing: () -> [DrawCommand]) {
        node = Node(type: .graphicsView, props: [.drawable: Self.value(drawing())])
    }

    /// A finger went down, or a mouse button was pressed.
    /// MAUI: GraphicsView.StartInteraction.
    ///
    /// The point is in the canvas's own coordinates - the same ones the drawing
    /// instructions use, so what arrives can be drawn where it happened.
    public func onStartInteraction(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        point(.startInteraction, handler)
    }

    /// It moved while still down, with where it is now - the canvas's own
    /// coordinates again. MAUI: GraphicsView.DragInteraction.
    public func onDragInteraction(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        point(.dragInteraction, handler)
    }

    /// It was lifted, with where it left off.
    /// MAUI: GraphicsView.EndInteraction.
    public func onEndInteraction(_ handler: @escaping ValueEventHandler<Point>) -> Self {
        point(.endInteraction, handler)
    }

    private func point(_ event: Event, _ handler: @escaping ValueEventHandler<Point>) -> Self {
        addHandler(event) {
            // A payload that will not parse leaves the handler alone, the way a
            // gesture's does: half a point is worse than none.
            if let point = Point(EventBuffer.current.value()) {
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
