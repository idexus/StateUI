// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties of a shape enclosing an area, shared by the control and its `Style`.
public protocol FilledShapeProperties: ShapeProperties {}

/// A shape enclosing an area its fill paints - every shape but a line.
public protocol FilledShape: Shape, FilledShapeProperties {}

extension FilledShapeProperties {
    /// What the inside of the shape is painted with.
    ///
    ///     Ellipse()
    ///         .fill(.linearGradient([GradientStop(.gold, 0), GradientStop(.tomato, 1)]))
    public func fill(_ value: Brush) -> Modified { setValue(FilledShapeContract.fill, value) }

    /// The same, in one color - `.fill(.solidColor(color))` said shortly.
    public func fill(_ value: Color) -> Modified { fill(.solidColor(value)) }
}

extension FilledShape {
    /// `fill` from a color state, `$x`: the host animates the color to each
    /// new value, and no view is rebuilt for it.
    public func fill(_ state: Binding<Color>) -> Modified {
        twin(FilledShapeContract.fill, carrying: state)
    }
}
