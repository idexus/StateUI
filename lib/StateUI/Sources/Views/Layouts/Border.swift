// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// `Border`'s own properties, shared by the control and its `Style<Border>`.
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
        setValue(BorderContract.stroke, value)
    }

    /// The same, in one colour - a solid brush.
    public func stroke(_ value: Color) -> Modified {
        stroke(.solidColor(value))
    }

    /// How wide the stroke is drawn, in device units - 1 unless said.
    ///
    /// A width of 0 draws no outline, which is how a Border is used for its
    /// shape alone, as the rounded corners on a coloured card.
    public func strokeWidth(_ value: Double) -> Modified {
        setValue(BorderContract.strokeWidth, value)
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
        setValue(BorderContract.shape, value)
    }

    // The rest of the stroke, as a shape carries it.
    // Design: docs/design/views/tiers.md#shapes

    /// The dashes and the gaps between them, in multiples of the stroke
    /// width.
    ///
    ///     Border { … }
    ///         .strokeWidth(2)
    ///         .strokeDashPattern([4, 2])
    public func strokeDashPattern(_ value: [Double]) -> Modified {
        setValue(BorderContract.strokeDashPattern, value)
    }

    /// How far into the dash pattern the outline starts.
    public func strokeDashOffset(_ value: Double) -> Modified {
        setValue(BorderContract.strokeDashOffset, value)
    }

    /// How the ends of each dash are drawn - and nothing at all on an outline
    /// with no dashes, a closed shape having no ends.
    public func strokeLineCap(_ value: LineCap) -> Modified {
        setValue(BorderContract.strokeLineCap, value)
    }

    /// How the outline turns a corner of the stroke shape.
    public func strokeLineJoin(_ value: LineJoin) -> Modified {
        setValue(BorderContract.strokeLineJoin, value)
    }

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke thickness - `.miter` corners only.
    public func strokeMiterLimit(_ value: Double) -> Modified {
        setValue(BorderContract.strokeMiterLimit, value)
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
/// Not to be confused with `BorderElement`, the outline a Button or a
/// RadioButton draws around itself.
public struct Border: View, PaddingElement, BorderProperties {
    /// The node this control describes.
    public var node: Node

    /// An empty one - what a `Style<Border>` is written against.
    public init() {
        node = Node(contract: BorderContract.self)
    }

    /// A border around what the closure describes: one view, so put a layout in
    /// it for more. The closure runs when the differ reaches the border.
    public init(@ViewBuilder content: @escaping () -> [Element]) {
        node = Node(contract: BorderContract.self)
        node.producer = { content().map { $0.body } }
    }

}

extension Border {
    /// `strokeDashOffset` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func strokeDashOffset(_ state: Binding<Double>) -> Modified {
        journey(BorderContract.strokeDashOffset.token, by: state)
    }

    /// `strokeLineCap` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func strokeLineCap(_ state: Binding<LineCap>) -> Modified {
        plain(BorderContract.strokeLineCap.token, by: state)
    }

    /// `strokeLineJoin` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func strokeLineJoin(_ state: Binding<LineJoin>) -> Modified {
        plain(BorderContract.strokeLineJoin.token, by: state)
    }

    /// `strokeMiterLimit` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func strokeMiterLimit(_ state: Binding<Double>) -> Modified {
        journey(BorderContract.strokeMiterLimit.token, by: state)
    }

    /// `strokeWidth` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func strokeWidth(_ state: Binding<Double>) -> Modified {
        journey(BorderContract.strokeWidth.token, by: state)
    }
}
