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
public struct Line: Shape {
    /// The node this control describes.
    public var node: Node

    /// Empty, for an initializer to fill.
    init() {
        node = Node(contract: LineContract.self)
    }

    /// A line from `start` to `end`.
    public init(from start: Point, to end: Point) {
        node = Node(contract: LineContract.self)
        node.write(LineContract.from, start)
        node.write(LineContract.to, end)
    }

    /// A line between two states' points, carried by the host as journeys: a write sends an end there under the
    /// element's motion, and no view is rebuilt for it.
    public init(from start: Binding<Point>, to end: Binding<Point>) {
        self = Line().from(start).to(end)
    }
}

extension Line {
    /// Where the line starts.
    func from(_ value: Point) -> Modified { setValue(LineContract.from, value) }

    /// Where it starts, from a state carried by the host as a journey.
    func from(_ state: Binding<Point>) -> Modified {
        twin(LineContract.from, by: state)
    }

    /// Where the line ends.
    func to(_ value: Point) -> Modified { setValue(LineContract.to, value) }

    /// Where it ends, from a state carried by the host as a journey.
    func to(_ state: Binding<Point>) -> Modified {
        twin(LineContract.to, by: state)
    }
}
