// MAUI: RoundRectangle.

/// RoundRectangle's own properties - the half a `Style<RoundRectangle>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol RoundRectangleProperties: PropertyContainer {}

extension RoundRectangleProperties {
    /// The same radius on all four corners, in device units.
    /// MAUI: RoundRectangle.CornerRadius.
    public func cornerRadius(_ value: Double) -> Modified {
        setValue(.cornerRadius, .number(value))
    }

    /// One corner at a time, each in device units. MAUI:
    /// RoundRectangle.CornerRadius, whose four-number form takes them in this
    /// order.
    ///
    ///     RoundRectangle()
    ///         .cornerRadius(topLeft: 16, topRight: 16, bottomLeft: 0, bottomRight: 0)
    ///         .fill(.whiteSmoke)
    ///
    /// A card rounded along the top and flush along the bottom, which is what
    /// naming them separately is for. The labels are required, so there is no
    /// order to remember at the call site.
    public func cornerRadius(
        topLeft: Double,
        topRight: Double,
        bottomLeft: Double,
        bottomRight: Double
    ) -> Modified {
        setValue(.cornerRadius, .numbers([topLeft, topRight, bottomLeft, bottomRight]))
    }
}

/// A rectangle with rounded corners, each one its own size if it has to be.
/// MAUI: RoundRectangle.
///
///     RoundRectangle()
///         .cornerRadius(12)
///         .fill(.whiteSmoke)
///         .heightRequest(80)
///
/// `Rectangle` rounds its corners with `radiusX`/`radiusY`, which are the same
/// for all four; this is the one that names them separately.
///
/// Like every shape, it has no size of its own - a `heightRequest`, a
/// `widthRequest` or a layout that stretches it is what gives it one.
public struct RoundRectangle: Shape, RoundRectangleProperties {
    /// The node this control describes.
    public var node: Node

    /// A rounded rectangle with nothing set - what a `Style<RoundRectangle>` is
    /// written against.
    public init() {
        node = Node(type: .roundRectangle)
    }

}
