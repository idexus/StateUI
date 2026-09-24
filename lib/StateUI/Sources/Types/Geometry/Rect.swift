// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A rectangle: a position and a size, in one value.
///
///     Label("Corner").absoluteLayoutBounds(Rect(0, 0, 120, 40))
///
/// What an `AbsoluteLayout` places a child with, and what a frame report
/// carries back. The numbers are device units unless the thing reading them
/// says otherwise - `absoluteLayoutProportions` is where that is said.
public struct Rect: Equatable, Sendable, HostRepresentable {
    /// The left edge, in device units - or a fraction of the layout's width when
    /// the bounds are proportional.
    public var x: Double

    /// The top edge, read the same way.
    public var y: Double

    /// How wide.
    public var width: Double

    /// How tall.
    public var height: Double

    /// In that order: x, y, width, height. What `Rect(0, 0, 120, 40)` means.
    public init(_ x: Double, _ y: Double, _ width: Double, _ height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    /// The same, said out loud - which a rectangle of four bare numbers usually
    /// wants:
    ///
    ///     Rect(x: 0, y: 0, width: 1, height: 0.5)
    public init(x: Double, y: Double, width: Double, height: Double) {
        self.init(x, y, width, height)
    }

    /// As a host is handed it: an array, in the initializer's order.
    public var propValue: PropValue {
        .numbers([x, y, width, height])
    }

    /// A rectangle back from its four numbers - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 4 else { return nil }

        self.init(numbers[0], numbers[1], numbers[2], numbers[3])
    }
}
