// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A rectangle: a position and a size, in one value.
///
///     Placement(Rect(x: 0, y: 0, width: 120, height: 40))
///
/// Where a placement stands a view, and what a frame report carries back, in
/// device units.
public struct Rect: Equatable, Sendable, HostRepresentable {
    /// The left edge.
    public var x: Double

    /// The top edge.
    public var y: Double

    /// How wide.
    public var width: Double

    /// How tall.
    public var height: Double

    /// A rectangle whose left edge is at `x` and top edge at `y`, `width` wide and `height` tall.
    ///
    ///     Rect(x: 0, y: 0, width: 1, height: 0.5)
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// No size at the origin - what a room stands at before it is measured.
    ///
    ///     @State private var room = Rect.zero
    public static let zero = Rect(x: 0, y: 0, width: 0, height: 0)

    /// As a host is handed it: an array, in the initializer's order.
    public var propValue: PropValue {
        .numbers([x, y, width, height])
    }

    /// A rectangle back from its four numbers - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 4 else { return nil }

        self.init(x: numbers[0], y: numbers[1], width: numbers[2], height: numbers[3])
    }
}
