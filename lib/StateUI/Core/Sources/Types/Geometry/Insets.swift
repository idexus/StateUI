// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Space on the four sides of something.
///
///     VStack { … }.padding(24)
///     Text("Total").margin(left: 0, top: 8, right: 0, bottom: 16)
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
        self.init(left: uniformSize, top: uniformSize, right: uniformSize, bottom: uniformSize)
    }

    /// Left and right first, then top and bottom.
    ///
    ///     Insets(horizontal: 16, vertical: 8)   // 16 either side, 8 above and below
    public init(horizontal: Double, vertical: Double) {
        self.init(left: horizontal, top: vertical, right: horizontal, bottom: vertical)
    }

    /// Each side by name.
    public init(left: Double, top: Double, right: Double, bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    /// As a host is handed it: an array, in the four-value initializer's order.
    public var propValue: PropValue {
        .numbers([left, top, right, bottom])
    }

    /// Insets back from their four numbers - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 4 else { return nil }

        self.init(left: numbers[0], top: numbers[1], right: numbers[2], bottom: numbers[3])
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
