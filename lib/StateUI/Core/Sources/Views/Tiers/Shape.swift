// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties every shape has, shared by the control and its `Style`.
public protocol ShapeProperties: ViewProperties {}

/// A drawn outline.
public protocol Shape: View, ShapeProperties {}

extension ShapeProperties {
    /// A transform applied to the shape's geometry before it is drawn, in the
    /// shape's own units about its own origin; the stroke follows the
    /// transformed path, and a `skew` draws exactly.
    ///
    ///     Line().x2(56).y2(0)
    ///         .renderTransform(.rotate(15).scaleX(1.2))
    ///
    /// `.transform(_:)` instead moves what was drawn, about the view's centre.
    public func renderTransform(_ value: ViewTransform) -> Modified {
        setValue(ShapeContract.renderTransform, value)
    }

    /// What the inside of the shape is painted with.
    ///
    ///     Ellipse().fill(.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]))
    public func fill(_ value: Brush) -> Modified { setValue(ShapeContract.fill, value) }

    /// The same, in one colour - `.fill(.solidColor(colour))` said shortly.
    public func fill(_ value: Color) -> Modified { fill(.solidColor(value)) }

    /// What the outline is painted with.
    public func stroke(_ value: Brush) -> Modified { setValue(ShapeContract.stroke, value) }

    /// The same, in one colour.
    public func stroke(_ value: Color) -> Modified { stroke(.solidColor(value)) }

    /// How thick the outline is, in device units - 1 unless said. A thickness
    /// with no `.stroke` draws nothing.
    public func strokeWidth(_ value: Double) -> Modified {
        setValue(ShapeContract.strokeWidth, value)
    }

    /// The dashes and the gaps between them, in multiples of the stroke
    /// thickness.
    ///
    ///     Line().x2(240)
    ///         .stroke(.lightGray)
    ///         .strokeWidth(2)
    ///         .strokeDashPattern([4, 2])   // 8 units of dash, 4 of gap
    public func strokeDashPattern(_ value: [Double]) -> Modified {
        setValue(ShapeContract.strokeDashPattern, value)
    }

    /// How far into the dash pattern the line starts.
    public func strokeDashOffset(_ value: Double) -> Modified {
        setValue(ShapeContract.strokeDashOffset, value)
    }

    /// How the ends of an open line are drawn.
    public func strokeLineCap(_ value: LineCap) -> Modified {
        setValue(ShapeContract.strokeLineCap, value)
    }

    /// How two segments meet at a corner.
    public func strokeLineJoin(_ value: LineJoin) -> Modified {
        setValue(ShapeContract.strokeLineJoin, value)
    }

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke thickness.
    public func strokeMiterLimit(_ value: Double) -> Modified {
        setValue(ShapeContract.strokeMiterLimit, value)
    }

    /// What the shape does with the room it is given - the `Aspect` an Image
    /// takes too. `.fit`, the default, scales the drawing to fit and keeps its
    /// proportions; `.center` keeps the size its own numbers say.
    public func aspect(_ value: Aspect) -> Modified { setValue(ShapeContract.aspect, value) }
}

extension Shape {
    /// `aspect` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func aspect(_ state: Binding<Aspect>) -> Modified {
        plain(ShapeContract.aspect, by: state)
    }

    /// `strokeDashOffset` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func strokeDashOffset(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.strokeDashOffset, by: state)
    }

    /// `strokeLineCap` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func strokeLineCap(_ state: Binding<LineCap>) -> Modified {
        plain(ShapeContract.strokeLineCap, by: state)
    }

    /// `strokeLineJoin` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func strokeLineJoin(_ state: Binding<LineJoin>) -> Modified {
        plain(ShapeContract.strokeLineJoin, by: state)
    }

    /// `strokeMiterLimit` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func strokeMiterLimit(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.strokeMiterLimit, by: state)
    }

    /// `strokeWidth` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func strokeWidth(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.strokeWidth, by: state)
    }
}
