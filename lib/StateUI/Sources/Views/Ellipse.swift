// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An oval filling the room it is given - a circle when that room is square.
///
///     Ellipse()
///         .fill(.tomato)
///         .width(48)
///         .height(48)
///
/// An ellipse IS its bounds, so it declares nothing of its own: the fill, the
/// stroke and the dash pattern all come from the shape tier in Elements.swift.
/// An outline needs a `.stroke`; the width defaults to 1, so
/// `.strokeWidth` is for a heavier or a finer one.
///
/// A round avatar or a status dot is this control sized square. For a rounded
/// RECTANGLE, use a `Rectangle` with a `cornerRadius`, or a `Border` with a
/// `.shape`.
public struct Ellipse: Shape {
    /// The node this control describes.
    public var node: Node

    /// An ellipse - which is also what a `Style<Ellipse>` is written against.
    public init() {
        node = Node(type: .ellipse)
    }
}
