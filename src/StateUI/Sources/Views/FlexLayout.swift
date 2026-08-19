// MAUI: FlexLayout.

/// FlexLayout's own properties - the half a `Style<FlexLayout>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol FlexLayoutProperties: PropertyContainer {}

extension FlexLayoutProperties {
    /// Which way the children run, and from which end.
    /// MAUI: FlexLayout.Direction.
    public func direction(_ value: FlexDirection) -> Modified {
        setValue(.direction, value.propValue)
    }

    /// Whether a line that runs out of room starts another.
    /// MAUI: FlexLayout.Wrap.
    public func wrap(_ value: FlexWrap) -> Modified {
        setValue(.wrap, value.propValue)
    }

    /// How the room left over ALONG the direction is shared out.
    /// MAUI: FlexLayout.JustifyContent.
    public func justifyContent(_ value: FlexJustify) -> Modified {
        setValue(.justifyContent, value.propValue)
    }

    /// Where each child sits ACROSS the direction.
    /// MAUI: FlexLayout.AlignItems.
    public func alignItems(_ value: FlexAlignItems) -> Modified {
        setValue(.alignItems, value.propValue)
    }

    /// The same for whole LINES, once the layout wraps. Does nothing while
    /// everything is on one line. MAUI: FlexLayout.AlignContent.
    public func alignContent(_ value: FlexAlignContent) -> Modified {
        setValue(.alignContent, value.propValue)
    }

    /// Whether the layout PLACES its children or only measures them, leaving
    /// each where the bounds it was given put it. MAUI: FlexLayout.Position.
    ///
    /// `.relative` is the default, in MAUI as here: the layout arranges its
    /// children, which is what every other property on a FlexLayout describes.
    public func position(_ value: FlexPosition) -> Modified {
        setValue(.position, value.propValue)
    }
}

/// Lays its children out in a line that can wrap, share out what is left over,
/// and let one child ask for more of it than the others.
///
///     FlexLayout {
///         ForEach(tags) { tag in
///             Label(tag)
///         }
///     }
///     .wrap(.wrap)
///     .justifyContent(.spaceEvenly)
///     .alignItems(.center)
///
/// CSS flexbox, which is what MAUI's is: `direction` and `wrap` say how the
/// lines run, `justifyContent` shares the room ALONG a line, and `alignItems`
/// and `alignContent` place things ACROSS it.
///
/// What one child wants for itself is written on the child - `.flexLayoutGrow`,
/// `.flexLayoutBasis` and the rest - the same rule `.gridRow` follows; see
/// Elements.swift.
///
/// The difference from a stack is that a stack has one answer for how big a
/// child is and this has three: what it asks for (`basis`), what it takes of the
/// surplus (`grow`), and what it gives up when there is not enough (`shrink`).
public struct FlexLayout: Layout, FlexLayoutProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<FlexLayout>` is written against.
    public init() {
        node = Node(type: .flexLayout)
    }

    /// A layout holding what the closure describes.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .flexLayout, children: content().map { $0.body })
    }

}
