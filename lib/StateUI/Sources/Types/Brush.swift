// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A brush and its three kinds: one colour, a gradient along a line, and a
// gradient out from a point, each crossing as its typed parts.
// Design: docs/design/types/brushes.md#the-wire-form

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
    /// Which of the three brushes this is, as the number that crosses; the
    /// kinds number from 1.
    /// Design: docs/design/types/vocabularies.md#a-kind-first
    enum Kind: Int32, Sendable {
        case solidColor = 1
        case linearGradient = 2
        case radialGradient = 3
    }

    let kind: Kind

    /// Nothing for a solid colour, the start and end points of a linear
    /// gradient, the centre and radius of a radial one.
    let geometry: [Double]

    /// The colours; one for a solid brush, whose offset does not cross.
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

    /// The kind, then its geometry and its stops.
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
