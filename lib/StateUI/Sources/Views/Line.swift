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
/// Each coordinate left unsaid is zero, so `.x2(240)` on its own
/// runs from the top left corner across. The four are modifiers rather than
/// arguments for the reason every property here is one - only what gives a
/// control its purpose goes in the initializer, and a line's purpose is not any
/// one of the four.
public struct Line: Shape, LineProperties {
    /// The node this control describes.
    public var node: Node

    /// A line with nothing set - what a `Style<Line>` is written against.
    public init() {
        node = Node(contract: LineContract.self)
    }
}

/// Line's own properties - the half a `Style<Line>` shares with the
/// control, beside what its tiers already carry. The control conforms on
/// the element side and the style on the property side, which is what
/// makes the same modifiers compile on both.
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
