// MAUI: Ellipse.

/// An oval filling the room it is given - a circle when that room is square.
///
///     Ellipse()
///         .fill(.tomato)
///         .widthRequest(48)
///         .heightRequest(48)
///
/// An ellipse IS its bounds, so it declares nothing of its own: the fill, the
/// stroke and the dash pattern all come from the shape tier in Elements.swift.
/// An outline needs a `.strokeThickness` beside its `.stroke`, a shape's
/// thickness defaulting to 0.
///
/// A round avatar or a status dot is this control sized square. For a rounded
/// RECTANGLE, use `RoundRectangle`, or a `Border` with a `.strokeShape`.
public struct Ellipse: Shape {
    /// The node this control describes.
    public var node: Node

    /// An ellipse - which is also what a `Style<Ellipse>` is written against.
    public init() {
        node = Node(type: .ellipse)
    }
}
