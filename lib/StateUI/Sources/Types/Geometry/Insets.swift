// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Space on the four sides of something.
///
///     VStack { … }.padding(24)
///     Label("Total").margin(0, 8, 0, 16)
///
/// `.padding` keeps it INSIDE the control, between its edge and its content;
/// `.margin` keeps it OUTSIDE, between the control and its neighbours. A
/// number written where one of these is wanted becomes the same value on all
/// four sides.
public struct Insets: Equatable, Sendable, HostRepresentable {
    /// The space on the left, in device units.
    public var left: Double

    /// The space above.
    public var top: Double

    /// The space on the right.
    public var right: Double

    /// The space below.
    public var bottom: Double

    /// The same value on all four sides.
    public init(_ uniformSize: Double) {
        self.init(uniformSize, uniformSize, uniformSize, uniformSize)
    }

    /// Left and right first, then top and bottom.
    ///
    ///     Insets(16, 8)   // 16 either side, 8 above and below
    public init(_ horizontalSize: Double, _ verticalSize: Double) {
        self.init(horizontalSize, verticalSize, horizontalSize, verticalSize)
    }

    /// Each side in turn: left, top, right, bottom - clockwise from the LEFT,
    /// not from the top.
    public init(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    /// The wire form: an array, in the four-value initializer's order.
    public var propValue: PropValue {
        .numbers([left, top, right, bottom])
    }

    /// Insets back from their four numbers - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 4 else { return nil }

        self.init(numbers[0], numbers[1], numbers[2], numbers[3])
    }
}

extension Insets: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    /// The same on all four sides, so `.padding(24)` needs no Insets written
    /// around it.
    public init(integerLiteral value: Int) {
        self.init(Double(value))
    }

    /// The same, for a fractional one.
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}
