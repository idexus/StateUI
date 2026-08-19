// MAUI: Border.

/// Border's own properties - the half a `Style<Border>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol BorderProperties: PropertyContainer {}

extension BorderProperties {
    /// What the outline is painted with. MAUI: Border.Stroke, which is a Brush.
    ///
    ///     Border { … }
    ///         .strokeThickness(3)
    ///         .stroke(.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]))
    ///
    /// It draws nothing without a `strokeThickness` above 0.
    public func stroke(_ value: Brush) -> Modified {
        setValue(.stroke, value.propValue)
    }

    /// The same, in one colour - which is what a border's outline usually is.
    ///
    /// One line over the brush form, so a border's stroke and a shape's put the
    /// SAME bytes on the wire for the same colour. Writing the bare colour out
    /// instead would have one property arrive in two shapes, and leave the host
    /// carrying a branch to tell them apart.
    public func stroke(_ value: Color) -> Modified {
        stroke(.solidColor(value))
    }

    /// How thick the stroke is drawn, in device units.
    /// MAUI: Border.StrokeThickness, whose default is 1.
    ///
    /// A thickness of 0 draws no outline however the stroke is painted - which
    /// is how a Border is used for its SHAPE alone, as the rounded corners on a
    /// coloured card.
    public func strokeThickness(_ value: Double) -> Modified {
        setValue(.strokeThickness, .number(value))
    }

    /// The shape the outline follows, and the shape the border's own
    /// background is painted to. MAUI: Border.StrokeShape.
    ///
    ///     Border { … }
    ///         .backgroundColor(.cornflowerBlue)
    ///         .strokeShape(.roundRectangle(12))
    ///         .strokeThickness(0)
    ///
    /// This is where a rounded corner comes from on anything that is not a
    /// Button or a BoxView: those two carry a `cornerRadius` of their own, and
    /// everything else is wrapped in a Border.
    public func strokeShape(_ value: StrokeShape) -> Modified {
        setValue(.strokeShape, value.propValue)
    }

    // The rest of MAUI's IStroke, which a Border carries as fully as a Shape
    // does. Written HERE rather than shared with the shape tier, and measured
    // against MAUI 10.0.20 rather than assumed: `Border.StrokeDashArrayProperty`
    // and `Shape.StrokeDashArrayProperty` are two separate BindableProperties
    // declared directly on two classes that share only the `IStroke` interface
    // - a Border is an `IBorderStroke`, a Shape an `IShapeView`, and neither
    // implements the other's. The same shape as ScrollView and ItemsView each
    // declaring a scrollbar visibility of their own; `stroke` and
    // `strokeThickness` above are this same pair said twice.

    /// The dashes and the gaps between them, in multiples of the stroke
    /// thickness. MAUI: Border.StrokeDashArray.
    ///
    ///     Border { … }
    ///         .strokeThickness(2)
    ///         .strokeDashArray([4, 2])
    public func strokeDashArray(_ value: [Double]) -> Modified {
        setValue(.strokeDashArray, .numbers(value))
    }

    /// How far into the dash pattern the outline starts.
    /// MAUI: Border.StrokeDashOffset.
    public func strokeDashOffset(_ value: Double) -> Modified {
        setValue(.strokeDashOffset, .number(value))
    }

    /// How the ends of each dash are drawn - and nothing at all on an outline
    /// with no dashes, a closed shape having no ends.
    /// MAUI: Border.StrokeLineCap.
    public func strokeLineCap(_ value: PenLineCap) -> Modified {
        setValue(.strokeLineCap, value.propValue)
    }

    /// How the outline turns a corner of the stroke shape.
    /// MAUI: Border.StrokeLineJoin.
    public func strokeLineJoin(_ value: PenLineJoin) -> Modified {
        setValue(.strokeLineJoin, value.propValue)
    }

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke thickness - `.miter` corners only.
    /// MAUI: Border.StrokeMiterLimit.
    public func strokeMiterLimit(_ value: Double) -> Modified {
        setValue(.strokeMiterLimit, .number(value))
    }
}

/// A single view with an outline around it.
///
///     Border {
///         Label("Inside")
///     }
///     .padding(16)
///     .stroke(.lightGray)
///     .strokeThickness(1)
///     .strokeShape(.roundRectangle(12))
///
/// The `.padding` is the room between the outline and what is inside it; the
/// `.margin` is the room outside the outline.
///
/// This is the general way to round a corner: give the border a
/// `.backgroundColor` and a `.strokeShape`, and the background follows the
/// shape whether or not the outline is drawn.
///
/// Not to be confused with `BorderElement`, the outline a Button, an
/// ImageButton and a RadioButton each draw around themselves - three flat
/// properties on the control, where this is a view of its own with a brush, a
/// shape and a dash pattern. See Views/BorderElement.swift.
public struct Border: View, PaddingElement, BorderProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Border>` is written against.
    public init() {
        node = Node(type: .border)
    }

    /// A border around what the closure describes. MAUI's Border holds ONE
    /// view; put a layout in it if there is more than one thing to show.
    public init(@ViewBuilder content: () -> [Element]) {
        node = Node(type: .border, children: content().map { $0.body })
    }

}
