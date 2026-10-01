// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A straight line between two points, in device units from the top left of the
/// space the line is given.
///
///     Line()
///         .x1(0).y1(0)
///         .x2(240).y2(0)
///         .stroke(.lightGray)
///         .strokeWidth(1)
///
/// A line with no stroke draws nothing: it has no inside for `fill` to paint.
///
/// Each coordinate left unsaid is zero, so `.x2(240)` on its own runs from the
/// top left corner across.
public struct Line: Shape, LineProperties {
    /// The node this control describes.
    public var node: Node

    /// A line with nothing set - what a `Style<Line>` is written against.
    public init() {
        node = Node(contract: LineContract.self)
    }
}

/// `Line`'s own properties, shared by the control and its `Style<Line>`.
public protocol LineProperties: PropertyContainer {}

extension LineProperties {
    /// Where it starts, across.
    public func x1(_ value: Double) -> Modified { setValue(LineContract.x1, value) }

    /// Where it starts, down.
    public func y1(_ value: Double) -> Modified { setValue(LineContract.y1, value) }

    /// Where it ends, across.
    public func x2(_ value: Double) -> Modified { setValue(LineContract.x2, value) }

    /// Where it ends, down.
    public func y2(_ value: Double) -> Modified { setValue(LineContract.y2, value) }
}

extension Line {
    /// `x1` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func x1(_ state: Binding<Double>) -> Modified {
        journey(.x1, by: state)
    }

    /// `x2` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func x2(_ state: Binding<Double>) -> Modified {
        journey(.x2, by: state)
    }

    /// `y1` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func y1(_ state: Binding<Double>) -> Modified {
        journey(.y1, by: state)
    }

    /// `y2` from a state, `$x`: the host animates the property to each new
    /// value, and no view is rebuilt for it.
    public func y2(_ state: Binding<Double>) -> Modified {
        journey(.y2, by: state)
    }
}
