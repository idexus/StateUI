// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Border's own properties - the half a `Style<Border>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
public protocol BorderProperties: PropertyContainer {}

extension BorderProperties {
    /// What the outline is painted with - any `Brush`, a gradient included.
    ///
    ///     Border { … }
    ///         .strokeWidth(3)
    ///         .stroke(.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]))
    ///
    /// It draws nothing without a `strokeWidth` above 0.
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

    /// How wide the stroke is drawn, in device units - 1 unless said.
    ///
    /// A width of 0 draws no outline however the stroke is painted - which
    /// is how a Border is used for its SHAPE alone, as the rounded corners on a
    /// coloured card.
    public func strokeWidth(_ value: Double) -> Modified {
        setValue(.strokeWidth, .number(value))
    }

    /// The shape the outline follows, and the shape the border's own
    /// background is painted to.
    ///
    ///     Border { … }
    ///         .background(.cornflowerBlue)
    ///         .shape(.roundedRectangle(12))
    ///         .strokeWidth(0)
    ///
    /// This is where a rounded corner comes from on anything without a
    /// `cornerRadius` of its own: a Button, a RadioButton, a ColorBox and a
    /// Rectangle carry one, and everything else is wrapped in a Border.
    public func shape(_ value: BorderShape) -> Modified {
        setValue(.shape, value.propValue)
    }

    // The rest of the stroke, which a Border carries as fully as a Shape does.
    // Written HERE rather than shared with the shape tier, because that tier
    // also carries `fill`, `renderTransform` and an `aspect` - a drawn
    // figure's, and none of them a Border's. The properties on the wire are
    // the same ones; `stroke` and `strokeWidth` above are this same pair
    // said twice.

    /// The dashes and the gaps between them, in multiples of the stroke
    /// width.
    ///
    ///     Border { … }
    ///         .strokeWidth(2)
    ///         .strokeDashPattern([4, 2])
    public func strokeDashPattern(_ value: [Double]) -> Modified {
        setValue(.strokeDashPattern, .numbers(value))
    }

    /// How far into the dash pattern the outline starts.
    public func strokeDashOffset(_ value: Double) -> Modified {
        setValue(.strokeDashOffset, .number(value))
    }

    /// How the ends of each dash are drawn - and nothing at all on an outline
    /// with no dashes, a closed shape having no ends.
    public func strokeLineCap(_ value: LineCap) -> Modified {
        setValue(.strokeLineCap, value.propValue)
    }

    /// How the outline turns a corner of the stroke shape.
    public func strokeLineJoin(_ value: LineJoin) -> Modified {
        setValue(.strokeLineJoin, value.propValue)
    }

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke thickness - `.miter` corners only.
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
///     .strokeWidth(1)
///     .shape(.roundedRectangle(12))
///
/// The `.padding` is the room between the outline and what is inside it; the
/// `.margin` is the room outside the outline.
///
/// This is the general way to round a corner: give the border a
/// `.background` and a `.shape`, and the background follows the
/// shape whether or not the outline is drawn.
///
/// Not to be confused with `BorderElement`, the outline a Button and a
/// RadioButton each draw around themselves - three flat properties on the
/// control, where this is a view of its own with a brush, a shape and a dash
/// pattern. See Views/BorderElement.swift.
public struct Border: View, PaddingElement, BorderProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Border>` is written against.
    public init() {
        node = Node(type: .border)
    }

    /// A border around what the closure describes. A Border holds ONE view;
    /// put a layout in it if there is more than one thing to show.
    /// The closure is kept and run when the differ describes the border.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(type: .border)
        node.producer = { content().map { $0.body } }
    }

}
