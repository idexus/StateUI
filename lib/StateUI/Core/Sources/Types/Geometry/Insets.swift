// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Space on the four sides of something. Its start and its end follow the
/// direction the element lays out in: the left and the right left to right,
/// the right and the left right to left.
///
///     VStack { … }.padding(24)
///     Text("Total").margin(start: 0, top: 8, end: 0, bottom: 16)
///
/// `.padding` keeps it INSIDE the control, between its edge and its content;
/// `.margin` keeps it OUTSIDE, between the control and its neighbours. A
/// number written where one of these is wanted becomes the same value on all
/// four sides.
public struct Insets: Equatable, Sendable, HostRepresentable {
    /// The space at the start, where a line of words starts, in device units.
    public var start: Double

    /// The space above.
    public var top: Double

    /// The space at the end, where a line of words ends.
    public var end: Double

    /// The space below.
    public var bottom: Double

    /// The same value on all four sides.
    public init(_ uniformSize: Double) {
        self.init(start: uniformSize, top: uniformSize, end: uniformSize, bottom: uniformSize)
    }

    /// The start and the end first, then top and bottom.
    ///
    ///     Insets(horizontal: 16, vertical: 8)   // 16 either side, 8 above and below
    public init(horizontal: Double, vertical: Double) {
        self.init(start: horizontal, top: vertical, end: horizontal, bottom: vertical)
    }

    /// Each side by name.
    public init(start: Double, top: Double, end: Double, bottom: Double) {
        self.start = start
        self.top = top
        self.end = end
        self.bottom = bottom
    }

    /// As a host is handed it: an array, in the four-value initializer's order.
    public var propValue: PropValue {
        .numbers([start, top, end, bottom])
    }

    /// Insets back from their four numbers - nil for anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let numbers = propValue.numbers, numbers.count == 4 else { return nil }

        self.init(start: numbers[0], top: numbers[1], end: numbers[2], bottom: numbers[3])
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
