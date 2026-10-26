// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The curve a phase layout's views follow between the poses its arithmetic answers at an axis's keyframes, one
/// number at a time: each view's place, size, turn, opacity and shade.
///
///     PhaseLayout(cards, id: \.name, phase: $arrangement) { … } placements: { room, phase in … }
///         .axis(\.self, input: .scroll(.horizontal), range: 0...2, keyframes: .every(1))
///         .interpolation(.catmullRom)
///
/// The library's curves are `.linear`, `.catmullRom` and `.monotone`; a curve of your own is a type conforming to
/// this protocol. Every curve passes through each keyframe, so a pose at a keyframe is the arithmetic's own.
/// Design: docs/design/views/phase-layout.md#keyframes
public protocol LayoutInterpolation: Sendable {
    /// How many keyframes either side of the two around a place the curve reads: none for straight lines between
    /// them, one for a curve their neighbors shape.
    var reach: Int { get }

    /// The number at `place`, which stands between `knots[segment]` and `knots[segment + 1]`, on the curve through
    /// `values` at `knots`.
    ///
    /// - Parameters:
    ///   - place: where on the axis, between the two keyframes.
    ///   - segment: the index of the keyframe before `place`.
    ///   - knots: the keyframes, lowest first: as many either side of the two as `reach` gives, fewer at an end of
    ///     the axis's range.
    ///   - values: the number at each keyframe.
    /// - Returns: the number at `place`.
    func value(at place: Double, segment: Int, knots: [Double], values: [Double]) -> Double
}

/// The curves this library draws through a layout's keyframes: `.linear`, `.catmullRom` and `.monotone`.
public struct LayoutCurve: LayoutInterpolation, Equatable {
    /// Straight, a cubic shaped by the neighbors' slopes, or a cubic that never passes its neighbors.
    fileprivate enum Kind: Equatable, Sendable {
        case linear
        case catmullRom(tension: Double)
        case monotone
    }

    private let kind: Kind

    fileprivate init(_ kind: Kind) {
        self.kind = kind
    }

    /// None for straight lines; one for a cubic, its slopes shaped by the neighbors.
    public var reach: Int { kind == .linear ? 0 : 1 }

    /// The number at `place` on this curve through `values` at `knots`.
    public func value(at place: Double, segment: Int, knots: [Double], values: [Double]) -> Double {
        let (x0, x1, y0, y1) = (knots[segment], knots[segment + 1], values[segment], values[segment + 1])
        let width = x1 - x0
        guard width > 0 else { return y0 }

        let along = (place - x0) / width
        switch kind {
        case .linear:
            return y0 + (y1 - y0) * along
        case .catmullRom(let tension):
            let slopes = (Self.slope(at: segment, knots, values), Self.slope(at: segment + 1, knots, values))
            return Self.hermite(along, y0, y1, slopes.0 * (1 - tension) * width, slopes.1 * (1 - tension) * width)
        case .monotone:
            let slopes = (Self.steffen(at: segment, knots, values), Self.steffen(at: segment + 1, knots, values))
            return Self.hermite(along, y0, y1, slopes.0 * width, slopes.1 * width)
        }
    }

    /// The slope through a keyframe's neighbors, the straight line's to its one neighbor at an end.
    private static func slope(at index: Int, _ knots: [Double], _ values: [Double]) -> Double {
        let before = max(index - 1, 0)
        let after = min(index + 1, knots.count - 1)
        return (values[after] - values[before]) / (knots[after] - knots[before])
    }

    /// The slope at a keyframe that keeps the curve between its neighbors: none where the values turn back there,
    /// at most twice the gentler side's.
    /// Design: docs/design/views/phase-layout.md#the-curves
    private static func steffen(at index: Int, _ knots: [Double], _ values: [Double]) -> Double {
        guard index > 0, index < knots.count - 1 else { return slope(at: index, knots, values) }

        let (left, right) = (knots[index] - knots[index - 1], knots[index + 1] - knots[index])
        let into = (values[index] - values[index - 1]) / left
        let out = (values[index + 1] - values[index]) / right
        guard into * out > 0 else { return 0 }

        let through = (into * right + out * left) / (left + right)
        let steepest = 2 * min(abs(into), abs(out))
        return abs(through) < steepest ? through : (into > 0 ? steepest : -steepest)
    }

    /// The cubic from `start` to `end` leaving and arriving at the given slopes, `along` the way from 0 to 1.
    private static func hermite(_ along: Double, _ start: Double, _ end: Double, _ leaving: Double, _ arriving: Double)
        -> Double
    {
        let (square, cube) = (along * along, along * along * along)
        return (2 * cube - 3 * square + 1) * start + (cube - 2 * square + along) * leaving
            + (-2 * cube + 3 * square) * end + (cube - square) * arriving
    }
}

extension LayoutInterpolation where Self == LayoutCurve {
    /// Straight lines from keyframe to keyframe: each view goes straight at an even pace, and turns at a keyframe.
    public static var linear: LayoutCurve { LayoutCurve(.linear) }

    /// A smooth curve through every keyframe, each view's way at one shaped by the keyframes either side - it may
    /// swing a little past a keyframe on its way.
    public static var catmullRom: LayoutCurve { LayoutCurve(.catmullRom(tension: 0)) }

    /// The same curve, held tighter: at a `tension` of 1 every view slows to a stop at each keyframe.
    ///
    /// - Parameter tension: from 0, the plain curve, to 1.
    /// - Returns: the curve.
    public static func catmullRom(tension: Double) -> LayoutCurve {
        LayoutCurve(.catmullRom(tension: tension.isFinite ? min(max(tension, 0), 1) : 0))
    }

    /// A smooth curve through every keyframe that never goes past one: each number stays between the keyframes
    /// either side, so an opacity or a size never swings beyond its poses'.
    public static var monotone: LayoutCurve { LayoutCurve(.monotone) }
}
