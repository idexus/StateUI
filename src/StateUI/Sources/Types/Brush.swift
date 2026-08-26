// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// MAUI: Brush, and the three kinds of it MAUI draws with.
//
// A brush travels as what it IS - a kind, its geometry, and its stops - and
// `SwiftValues.GetBrush` builds the MAUI object from that, because MAUI's own
// `BrushTypeConverter` reads the CSS spelling only partially, and measurably:
//
//     linear-gradient(to right, red, blue)         -> a brush with NO stops
//     linear-gradient(to right, #FF0000, #0000FF)  -> stops at offset -1
//     linear-gradient(to bottom right, …)          -> the points of `to right`
//
// Each of those produces a Brush that draws nothing, or draws the wrong thing,
// and none of them says a word. `FlexBasis` travels as its parts too, for the
// neighbouring reason: MAUI's converter for that one is internal rather than
// lossy.
//
// The wire form is a list of typed VALUES, the kind first as the number both
// sides spell:
//
//     solid   [1, colour]
//     linear  [2, [x1,y1,x2,y2], offset, colour, offset, colour, …]
//     radial  [3, [cx,cy,r],     offset, colour, offset, colour, …]
//
// Each stop's colour has already picked its half for the theme in force, so a
// gradient written with `Color(light:dark:)` is one gradient here and the view
// that wrote it is rebuilt when the system flips.

/// One colour in a gradient, and where along it that colour sits.
/// MAUI: GradientStop.
///
///     GradientStop(.cornflowerBlue, 0)
///     GradientStop(Color(light: .white, dark: .black), 1)
///
/// The offset runs from 0 at the start of the gradient to 1 at its end, where
/// "start" and "end" are the points the gradient itself was given.
public struct GradientStop: Equatable, Sendable {
    /// What colour the gradient is at this point. MAUI: GradientStop.Color.
    public let color: Color

    /// Where along the gradient it is, from 0 to 1.
    /// MAUI: GradientStop.Offset.
    public let offset: Double

    /// A stop, written the way MAUI's constructor takes one: the colour, then
    /// how far along it sits.
    public init(_ color: Color, _ offset: Double) {
        self.color = color
        self.offset = offset
    }
}

/// What MAUI paints a shape, a border or a background with. MAUI: Brush.
///
///     .fill(.solidColor(.tomato))
///     .background(.linearGradient([
///         GradientStop(.cornflowerBlue, 0),
///         GradientStop(.indigo, 1),
///     ], startPoint: Point(0, 0), endPoint: Point(1, 1)))
///
/// A brush is where a gradient goes: `.backgroundColor` takes one colour, and
/// `.background` takes one of these.
public struct Brush: Equatable, Sendable {
    /// Which of MAUI's three brushes this is, as the number that crosses - a
    /// closed vocabulary, so it rides its member rather than a spelling.
    /// Mirrored by `SwiftBrushKind`, and the numbers are this library's own,
    /// like every other vocabulary's: see the head of Types/Enums.swift.
    ///
    /// It numbers from 1 rather than 0, alone among them: a wire contract asks
    /// only that both sides say the same number, never where the count begins.
    enum Kind: Int32, Sendable {
        case solidColor = 1
        case linearGradient = 2
        case radialGradient = 3
    }

    let kind: Kind

    /// What the brush is drawn over: nothing for a solid colour, the start
    /// and end points of a linear gradient, the centre and radius of a radial
    /// one.
    let geometry: [Double]

    /// The colours. Exactly one for a solid brush, whose offset is not asked
    /// for and does not travel.
    let stops: [GradientStop]

    private init(_ kind: Kind, geometry: [Double] = [], stops: [GradientStop]) {
        self.kind = kind
        self.geometry = geometry
        self.stops = stops
    }

    /// One colour, everywhere. MAUI: SolidColorBrush.
    ///
    /// The same thing `.backgroundColor` sets, said as a brush - which is what
    /// a property typed `Brush` wants.
    public static func solidColor(_ color: Color) -> Brush {
        Brush(.solidColor, stops: [GradientStop(color, 0)])
    }

    /// A gradient along a line. MAUI: LinearGradientBrush.
    ///
    ///     .linearGradient([
    ///         GradientStop(.gold, 0),
    ///         GradientStop(.tomato, 1),
    ///     ], startPoint: Point(0, 0), endPoint: Point(1, 0))
    ///
    /// The points are fractions of the thing being painted, not device units:
    /// `Point(0, 0)` is its top left corner and `Point(1, 1)` its bottom right.
    /// Left unwritten they are `Point(0, 0)` and `Point(0, 1)`, which runs the
    /// gradient straight down.
    ///
    /// - Parameters:
    ///   - stops: the colours, and how far along each one sits.
    ///   - startPoint: where the gradient begins. MAUI: LinearGradientBrush.StartPoint.
    ///   - endPoint: where it ends. MAUI: LinearGradientBrush.EndPoint.
    public static func linearGradient(
        _ stops: [GradientStop],
        startPoint: Point = Point(0, 0),
        endPoint: Point = Point(0, 1)
    ) -> Brush {
        Brush(
            .linearGradient,
            geometry: [startPoint.x, startPoint.y, endPoint.x, endPoint.y],
            stops: stops)
    }

    /// A gradient out from a point. MAUI: RadialGradientBrush.
    ///
    ///     .radialGradient([
    ///         GradientStop(.white, 0),
    ///         GradientStop(.steelBlue, 1),
    ///     ], center: Point(0.3, 0.3), radius: 0.8)
    ///
    /// The centre is a fraction of the thing being painted and the radius a
    /// fraction of its size, which is MAUI's own reading of both.
    ///
    /// - Parameters:
    ///   - stops: the colours, from the centre outwards.
    ///   - center: where the gradient starts from. MAUI: RadialGradientBrush.Center.
    ///   - radius: how far out it reaches. MAUI: RadialGradientBrush.Radius.
    public static func radialGradient(
        _ stops: [GradientStop],
        center: Point = Point(0.5, 0.5),
        radius: Double = 0.5
    ) -> Brush {
        Brush(.radialGradient, geometry: [center.x, center.y, radius], stops: stops)
    }

    /// The kind, then what that kind is made of - see the note at the top of
    /// the file.
    var propValue: PropValue {
        var values: [PropValue] = [.enumeration(kind.rawValue)]

        switch kind {
        case .solidColor:
            values += stops.map { $0.color.propValue }

        case .linearGradient, .radialGradient:
            values.append(.numbers(geometry))
            values += stops.flatMap { [.number($0.offset), $0.color.propValue] }
        }

        return .values(values)
    }
}
