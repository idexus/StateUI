// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A brush, and its three kinds: one colour, a gradient along a line, and a
// gradient out from a point.
//
// A brush travels as what it IS - a kind, its geometry, and its stops - and
// the host builds its own toolkit's brush from those, parsing nothing. A
// gradient spelled as text would put the definition of a gradient inside
// whichever parser reads it, and a parser that read it only partially would
// draw nothing, or the wrong thing, without saying a word.
//
// The wire form is a list of typed VALUES, the kind first as the number both
// sides spell:
//
//     solid   [1, colour]
//     linear  [2, [x1,y1,x2,y2], offset, colour, offset, colour, …]
//     radial  [3, [cx,cy,r],     offset, colour, offset, colour, …]
//
// A stop written with `Color(light:dark:)` crosses as both halves until the
// differ builds the element wearing the brush and picks the half in force, and
// that element is built again when the system flips.

/// One colour in a gradient, and where along it that colour sits.
///
///     GradientStop(.cornflowerBlue, 0)
///     GradientStop(Color(light: .white, dark: .black), 1)
///
/// The offset runs from 0 at the start of the gradient to 1 at its end, where
/// "start" and "end" are the points the gradient itself was given.
public struct GradientStop: Equatable, Sendable {
    /// What colour the gradient is at this point.
    public let color: Color

    /// Where along the gradient it is, from 0 to 1.
    public let offset: Double

    /// A stop: the colour, then how far along it sits.
    public init(_ color: Color, _ offset: Double) {
        self.color = color
        self.offset = offset
    }
}

/// What a shape, a border or a background is painted with.
///
///     .fill(.solidColor(.tomato))
///     .background(.linearGradient([
///         GradientStop(.cornflowerBlue, 0),
///         GradientStop(.indigo, 1),
///     ], startPoint: Point(0, 0), endPoint: Point(1, 1)))
///
/// A brush is where a gradient goes: `.background` takes one colour or one of
/// these.
public struct Brush: Equatable, Sendable, HostRepresentable {
    /// Which of the three brushes this is, as the number that crosses - a
    /// closed vocabulary, so it rides its member rather than a spelling. The
    /// numbers are this library's own, like every other vocabulary's: see the
    /// head of Types/Enums.swift.
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

    /// One colour, everywhere.
    ///
    /// A colour said as a brush, for a property that takes only a brush.
    public static func solidColor(_ color: Color) -> Brush {
        Brush(.solidColor, stops: [GradientStop(color, 0)])
    }

    /// A gradient along a line.
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
    ///   - startPoint: where the gradient begins.
    ///   - endPoint: where it ends.
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

    /// A gradient out from a point.
    ///
    ///     .radialGradient([
    ///         GradientStop(.white, 0),
    ///         GradientStop(.steelBlue, 1),
    ///     ], center: Point(0.3, 0.3), radius: 0.8)
    ///
    /// The centre is a fraction of the thing being painted and the radius a
    /// fraction of its size.
    ///
    /// - Parameters:
    ///   - stops: the colours, from the centre outwards.
    ///   - center: where the gradient starts from.
    ///   - radius: how far out it reaches.
    public static func radialGradient(
        _ stops: [GradientStop],
        center: Point = Point(0.5, 0.5),
        radius: Double = 0.5
    ) -> Brush {
        Brush(.radialGradient, geometry: [center.x, center.y, radius], stops: stops)
    }

    /// The kind, then what that kind is made of - see the note at the top of
    /// the file.
    public var propValue: PropValue {
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

    /// A brush back: its kind, then what that kind is made of - nil for
    /// anything else.
    /// - Parameter propValue: what the host sent.
    public init?(propValue: PropValue) {
        guard let values = propValue.values,
              let kind = values.first?.enumeration.flatMap(Kind.init(rawValue:))
        else { return nil }

        switch kind {
        case .solidColor:
            guard values.count == 2, let color = Color(propValue: values[1]) else { return nil }

            self = .solidColor(color)

        case .linearGradient, .radialGradient:
            guard values.count >= 2, let geometry = values[1].numbers, values.count % 2 == 0 else {
                return nil
            }

            var stops: [GradientStop] = []

            for index in stride(from: 2, to: values.count, by: 2) {
                guard let offset = values[index].number,
                      let color = Color(propValue: values[index + 1])
                else { return nil }

                stops.append(GradientStop(color, offset))
            }

            self.init(kind, geometry: geometry, stops: stops)
        }
    }
}
