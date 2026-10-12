// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The properties of a shape whose outline turns corners, shared by the control and its `Style`.
public protocol CorneredShapeProperties: ShapeProperties {}

/// A shape whose outline turns corners - a rectangle, a polygon, a polyline, a path.
public protocol CorneredShape: Shape, CorneredShapeProperties {}

extension CorneredShapeProperties {
    /// How two segments meet at a corner.
    public func lineJoin(_ value: LineJoin) -> Modified {
        setValue(CorneredShapeContract.lineJoin, value)
    }

    /// How far a sharp corner may reach before it is cut off, in multiples of
    /// the stroke thickness.
    public func miterLimit(_ value: Double) -> Modified {
        setValue(CorneredShapeContract.miterLimit, value)
    }
}

extension CorneredShape {
    /// `lineJoin` from a state, `$x`: the host sets each new value as it
    /// stands, and no view is rebuilt for it.
    public func lineJoin(_ state: Binding<LineJoin>) -> Modified {
        twin(CorneredShapeContract.lineJoin, by: state)
    }

    /// `miterLimit` from a state, `$x`: the host animates the property to
    /// each new value, and no view is rebuilt for it.
    public func miterLimit(_ state: Binding<Double>) -> Modified {
        twin(CorneredShapeContract.miterLimit, by: state)
    }
}
