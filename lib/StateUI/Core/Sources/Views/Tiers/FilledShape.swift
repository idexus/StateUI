// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties of a shape enclosing an area, shared by the control and its `Style`.
public protocol FilledShapeProperties: ShapeProperties {}

/// A shape enclosing an area its fill paints - every shape but a line.
public protocol FilledShape: Shape, FilledShapeProperties {}

extension FilledShapeProperties {
    /// What the inside of the shape is made of: a color, a gradient, a blur of what lies behind it, or the platform's
    /// glass, cut to the figure; a `Material(light:dark:)` follows the theme.
    ///
    ///     Capsule()
    ///         .fill(.blur(.thin))
    public func fill(_ value: Material) -> Modified { setValue(FilledShapeContract.fill, value) }

    /// The inside in one color.
    public func fill(_ value: Color) -> Modified { fill(.color(value)) }

    /// The inside in a gradient.
    ///
    ///     Ellipse()
    ///         .fill(.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]))
    public func fill(_ value: Brush) -> Modified { fill(.gradient(value)) }
}

extension FilledShape {
    /// `fill` from a color state, `$x`: the host animates the color to each
    /// new value, and no view is rebuilt for it.
    public func fill(_ state: Binding<Color>) -> Modified {
        twin(FilledShapeContract.fill, carrying: state)
    }

    /// `fill` from a material state, `$x`: the host shows each new material as it stands, and no view is rebuilt
    /// for it.
    public func fill(_ state: Binding<Material>) -> Modified {
        twin(FilledShapeContract.fill, by: state)
    }
}
