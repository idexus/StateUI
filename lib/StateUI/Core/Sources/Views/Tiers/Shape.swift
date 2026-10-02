// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties every shape has, shared by the control and its `Style`.
public protocol ShapeProperties: ViewProperties {}

/// A drawn outline.
public protocol Shape: ElementView, ShapeProperties {}

extension ShapeProperties {
    /// A transform applied to the shape's geometry before it is drawn, in the
    /// shape's own units about its own origin; the stroke follows the
    /// transformed path, and a `skew` draws exactly.
    ///
    ///     Line().x2(56).y2(0)
    ///         .geometryTransform(.rotate(15).scaleX(1.2))
    ///
    /// `.transform(_:)` instead moves what was drawn, about the view's centre.
    public func geometryTransform(_ value: ViewTransform) -> Modified {
        setValue(ShapeContract.geometryTransform, value)
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
    public func lineWidth(_ value: Double) -> Modified {
        setValue(ShapeContract.lineWidth, value)
    }

    /// The dashes and the gaps between them, in multiples of the stroke
    /// thickness.
    ///
    ///     Line().x2(240)
    ///         .stroke(.lightGray)
    ///         .lineWidth(2)
    ///         .dash([4, 2])   // 8 units of dash, 4 of gap
    public func dash(_ value: [Double]) -> Modified {
        setValue(ShapeContract.dash, value)
    }

    /// How far into the dash pattern the line starts.
    public func dashPhase(_ value: Double) -> Modified {
        setValue(ShapeContract.dashPhase, value)
    }

    /// How the ends of an open line are drawn.
    public func lineCap(_ value: LineCap) -> Modified {
        setValue(ShapeContract.lineCap, value)
    }

    /// How two segments meet at a corner.
    public func lineJoin(_ value: LineJoin) -> Modified {
        setValue(ShapeContract.lineJoin, value)
    }

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke thickness.
    public func miterLimit(_ value: Double) -> Modified {
        setValue(ShapeContract.miterLimit, value)
    }

    /// What the shape does with the room it is given - the `ContentMode` an Image
    /// takes too. `.fit`, the default, scales the drawing to fit and keeps its
    /// proportions; `.center` keeps the size its own numbers say.
    public func contentMode(_ value: ContentMode) -> Modified { setValue(ShapeContract.contentMode, value) }
}

extension Shape {
    /// `aspect` from a state, `$x`: the host sets each new value as it stands,
    /// and no view is rebuilt for it.
    public func contentMode(_ state: Binding<ContentMode>) -> Modified {
        plain(ShapeContract.contentMode, by: state)
    }

    /// `dashPhase` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func dashPhase(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.dashPhase, by: state)
    }

    /// `lineCap` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func lineCap(_ state: Binding<LineCap>) -> Modified {
        plain(ShapeContract.lineCap, by: state)
    }

    /// `lineJoin` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func lineJoin(_ state: Binding<LineJoin>) -> Modified {
        plain(ShapeContract.lineJoin, by: state)
    }

    /// `miterLimit` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func miterLimit(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.miterLimit, by: state)
    }

    /// `lineWidth` from a state, `$x`: the host animates the property to each
    /// new value, and no view is rebuilt for it.
    public func lineWidth(_ state: Binding<Double>) -> Modified {
        journey(ShapeContract.lineWidth, by: state)
    }
}
