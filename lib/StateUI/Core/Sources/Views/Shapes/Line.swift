// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A straight line between two points, in device units from the top left of the
/// space the line is given.
///
///     Line(from: Point(0, 0), to: Point(240, 0))
///         .stroke(.lightGray)
///         .lineWidth(1)
///
/// A line is drawn by its stroke alone: it encloses nothing to fill.
///
/// A point left unsaid is the top left corner, so `Line().to(Point(240, 0))`
/// runs from it across.
public struct Line: Shape, LineProperties {
    /// The node this control describes.
    public var node: Node

    /// A line with nothing set - what a `Style<Line>` is written against.
    public init() {
        node = Node(contract: LineContract.self)
    }

    /// A line from `start` to `end`.
    public init(from start: Point, to end: Point) {
        node = Node(contract: LineContract.self)
        node.write(LineContract.from, start)
        node.write(LineContract.to, end)
    }
}

/// `Line`'s own properties, shared by the control and its `Style<Line>`.
public protocol LineProperties: PropertyContainer {}

extension LineProperties {
    /// Where it starts.
    public func from(_ value: Point) -> Modified { setValue(LineContract.from, value) }

    /// Where it ends.
    public func to(_ value: Point) -> Modified { setValue(LineContract.to, value) }
}

extension Line {
    /// `from` from a state, `$start`: the host animates the start to each new
    /// point, and no view is rebuilt for it.
    public func from(_ state: Binding<Point>) -> Modified {
        twin(LineContract.from, by: state)
    }

    /// `to` from a state, `$end`: the host animates the end to each new point,
    /// and no view is rebuilt for it.
    public func to(_ state: Binding<Point>) -> Modified {
        twin(LineContract.to, by: state)
    }
}
