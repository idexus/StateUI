// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A point.
///
/// Where a gesture happened in the view's own coordinates, where a polygon
/// turns a corner, or where a gradient begins. Its units belong to the property
/// that reads it.
public struct Point: Equatable, Sendable {
    /// How far across, from the left edge. Device units where the property
    /// reading it works in those - a pointer's position, a polygon's corner -
    /// and a fraction of the view where it works in fractions, as a gradient's
    /// start and end points do.
    public var x: Double

    /// How far down, from the top edge, read the same way.
    public var y: Double

    /// A point.
    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    /// The same without labels, for a list where the labels would drown the
    /// numbers.
    ///
    ///     Polygon([Point(20, 0), Point(40, 40), Point(0, 40)])
    public init(_ x: Double, _ y: Double) {
        self.init(x: x, y: y)
    }

    /// The origin: both numbers 0.
    ///
    ///     @State private var offset = Point.zero
    ///
    /// As a place it is the top left corner; as a distance - a drag so far, a
    /// scroller's offset - it is no distance at all.
    public static let zero = Point(0, 0)
}

extension Point: HostRepresentable {
    /// Across, then down: one pair of numbers - what a pointer's position
    /// crosses as.
    public var propValue: PropValue { .numbers([x, y]) }

    /// A point back from its pair - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let pair = propValue.numbers, pair.count == 2 else { return nil }

        self.init(x: pair[0], y: pair[1])
    }

    /// Points cross as one flat run of numbers, x then y for each point - a
    /// polygon's or a polyline's corners.
    /// - Parameter list: the points, in order.
    public static func propValue(of list: [Point]) -> PropValue {
        .numbers(list.flatMap { [$0.x, $0.y] })
    }

    /// The points back from their run of pairs - nil for an odd run or for
    /// anything else.
    /// - Parameter value: what the host sent.
    public static func list(from value: PropValue) -> [Point]? {
        guard let numbers = value.numbers, numbers.count.isMultiple(of: 2) else { return nil }

        return stride(from: 0, to: numbers.count, by: 2).map { Point(numbers[$0], numbers[$0 + 1]) }
    }
}
