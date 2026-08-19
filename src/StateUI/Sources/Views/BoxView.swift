// MAUI: BoxView.

/// BoxView's own properties - the half a `Style<BoxView>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol BoxViewProperties: PropertyContainer {}

extension BoxViewProperties {
    /// What the rectangle is filled with. MAUI: BoxView.Color.
    ///
    /// Not `.backgroundColor`: a BoxView carries both, and this is the one it
    /// draws - the background is the square behind it, which the corner radius
    /// does not round.
    public func color(_ value: Color) -> Modified {
        setValue(.color, value.propValue)
    }

    /// How rounded the corners are, in device units - the same radius on all
    /// four. MAUI: BoxView.CornerRadius.
    ///
    /// A radius of half the side turns a square box into a circle.
    public func cornerRadius(_ value: Double) -> Modified {
        setValue(.cornerRadius, .number(value))
    }

    /// One corner at a time, in MAUI's order.
    ///
    ///     BoxView().cornerRadius(topLeft: 16, topRight: 16, bottomLeft: 0, bottomRight: 0)
    ///
    /// - Parameters:
    ///   - topLeft: the top left corner.
    ///   - topRight: the top right corner.
    ///   - bottomLeft: the bottom left corner.
    ///   - bottomRight: the bottom right corner.
    public func cornerRadius(
        topLeft: Double,
        topRight: Double,
        bottomLeft: Double,
        bottomRight: Double
    ) -> Modified {
        setValue(.cornerRadius, .numbers([topLeft, topRight, bottomLeft, bottomRight]))
    }
}

/// A rectangle of colour.
///
///     BoxView()
///         .color(.cornflowerBlue)
///         .cornerRadius(8)
///         .heightRequest(40)
///
/// The simplest thing MAUI draws: a divider, a bar of a chart, a placeholder,
/// or a deliberate piece of empty space. It has no content and no children -
/// for a coloured area around something, use a `Border`.
public struct BoxView: View, BoxViewProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<BoxView>` is written against.
    public init() {
        node = Node(type: .boxView)
    }

    /// A rectangle drawn in `color`. Sized by `.widthRequest` and
    /// `.heightRequest`, or by the room the layout gives it.
    public init(_ color: Color) {
        node = Node(type: .boxView, props: [.color: color.propValue])
    }

}
