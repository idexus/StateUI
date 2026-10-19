// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Places on an axis of a layout engine's phase, beside the ends of its range, which are always among them: where
/// the axis may come to rest under the user's hand (`snaps:`), and where its layout is worked out (`keyframes:`).
/// This library's own.
///
///     .axis(\.x, input: .scroll(.horizontal), range: 0...3, snaps: [1, 2])      // 0, 1, 2, 3
///     .axis(\.x, input: .scroll(.horizontal), range: 0...3, snaps: .limits)     // 0, 3
///     .axis(\.x, input: .scroll(.horizontal), range: 0...3, snaps: .every(1))   // 0, 1, 2, 3
///
/// An axis given no snaps rests wherever its throw ends inside its range.
/// Design: docs/design/views/layout-engine.md#an-axis
public struct LayoutPlaces: Equatable, Sendable, ExpressibleByArrayLiteral {
    /// The places listed, or a step from the lower end.
    private enum Places: Equatable, Sendable {
        case listed([Double])
        case every(Double)
    }

    private let places: Places

    /// The ends of the range alone: as snaps, let go anywhere, the axis comes onto the nearer end.
    public static var limits: LayoutPlaces { LayoutPlaces(places: .listed([])) }

    /// Every `step` from the lower end of the range, and the upper end.
    ///
    ///     .axis(\.turn, input: .rotation(degreesPerUnit: 360), range: 0...1, snaps: .every(0.25), wraps: true)
    ///
    /// - Parameter step: how far apart the places are; above nought.
    /// - Returns: the places.
    public static func every(_ step: Double) -> LayoutPlaces {
        LayoutPlaces(places: step.isFinite && step > 0 ? .every(step) : .listed([]))
    }

    /// The places `values` lists, and the ends of the range: a list worked out, which a literal cannot take.
    ///
    ///     .axis(\.self, input: .scroll(.horizontal), range: 0...10, snaps: .at(chapters.map(\.start)))
    ///
    /// - Parameter values: the places inside the range; those outside it are left out.
    /// - Returns: the places.
    public static func at(_ values: some Sequence<Double>) -> LayoutPlaces {
        LayoutPlaces(places: .listed(Array(values)))
    }

    private init(places: Places) {
        self.places = places
    }

    /// The places listed, and the ends of the range.
    public init(arrayLiteral values: Double...) {
        places = .listed(values)
    }

    /// The places in `range`, lowest first, its ends included - its upper end left out where the axis `wraps`, as it
    /// is the lower one a turn on.
    func values(in range: ClosedRange<Double>, wraps: Bool) -> [Double] {
        let (low, high) = (range.lowerBound, range.upperBound)
        let inside: [Double]
        switch places {
        case .listed(let values):
            inside = values.filter { $0.isFinite && $0 > low && $0 < high }
        case .every(let step):
            // A place a rounding short of the upper end is the end.
            let count = Int(min((high - low) / step, Self.most).rounded(.down))
            inside = count > 0 ? (1...count).map { low + Double($0) * step }.filter { $0 < high - step * 1e-6 } : []
        }

        let ends = wraps ? [low] : [low, high]
        return Array(Set(ends + inside)).sorted()
    }

    /// The most places a step makes.
    private static var most: Double { 10_000 }
}
