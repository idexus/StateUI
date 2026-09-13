// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// Thickness, as MAUI defines it.
//
// The three initializers mirror MAUI's three constructors exactly, the order of
// the four-value one included: left, top, right, bottom. A numeric literal is
// one too, so the common case reads as `.padding(24)` rather than
// `.padding(Thickness(24))`.

/// Space on the four sides of something. MAUI: Thickness.
///
///     VStack { … }.padding(24)
///     Label("Total").margin(0, 8, 0, 16)
///
/// `.padding` keeps it INSIDE the control, between its edge and its content;
/// `.margin` keeps it OUTSIDE, between the control and its neighbours. A
/// number written where one of these is wanted becomes the same value on all
/// four sides.
public struct Thickness: Equatable, Sendable {
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

    /// Left and right first, then top and bottom - MAUI's two-value
    /// constructor, and the order XAML's `16,8` is read in.
    ///
    ///     Thickness(16, 8)   // 16 either side, 8 above and below
    public init(_ horizontalSize: Double, _ verticalSize: Double) {
        self.init(horizontalSize, verticalSize, horizontalSize, verticalSize)
    }

    /// Each side in turn, in MAUI's order: left, top, right, bottom -
    /// clockwise from the LEFT, where CSS's four-value shorthand starts at the
    /// top.
    public init(_ left: Double, _ top: Double, _ right: Double, _ bottom: Double) {
        self.left = left
        self.top = top
        self.right = right
        self.bottom = bottom
    }

    /// The wire form: an array, in the order MAUI's constructor takes them.
    var propValue: PropValue {
        .numbers([left, top, right, bottom])
    }
}

extension Thickness: ExpressibleByIntegerLiteral, ExpressibleByFloatLiteral {
    /// The same on all four sides, so `.padding(24)` needs no Thickness written
    /// around it.
    public init(integerLiteral value: Int) {
        self.init(Double(value))
    }

    /// The same, for a fractional one.
    public init(floatLiteral value: Double) {
        self.init(value)
    }
}
