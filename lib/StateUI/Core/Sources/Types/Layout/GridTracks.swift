// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A run of a grid's rows or columns, each as long as one `GridLength` says, as many as `count` says - one where it
/// says nothing.
///
///     Grid { … }
///         .rows(.fill, .auto(count: 2), .fill(count: 5), .fixed(80))
///
/// A count below one writes no row or column.
public struct GridTracks: Equatable, Sendable {
    /// How long each row or column of the run is.
    public let length: GridLength

    /// How many rows or columns the run holds.
    public let count: Int

    /// A run of `count` rows or columns, each `length` long.
    public init(_ length: GridLength, count: Int = 1) {
        self.length = length
        self.count = count
    }

    /// One row or column as tall or wide as what it holds.
    public static var auto: GridTracks { GridTracks(.auto) }

    /// One row or column taking one share of what is left over.
    public static var fill: GridTracks { GridTracks(.fill) }

    /// `count` rows or columns, each as tall or wide as what it holds.
    public static func auto(count: Int) -> GridTracks { GridTracks(.auto, count: count) }

    /// `count` rows or columns, each taking one share of what is left over.
    public static func fill(count: Int) -> GridTracks { GridTracks(.fill, count: count) }

    /// `count` rows or columns, each taking `share` of what is left over, in proportion to the other shares.
    public static func proportional(_ share: Double, count: Int = 1) -> GridTracks {
        GridTracks(.proportional(share), count: count)
    }

    /// `count` rows or columns, each exactly `length` device units.
    public static func fixed(_ length: Double, count: Int = 1) -> GridTracks {
        GridTracks(.fixed(length), count: count)
    }

    /// The lengths of `runs`, one a row or column, in order.
    static func lengths(_ runs: [GridTracks]) -> [GridLength] {
        runs.flatMap { Array(repeating: $0.length, count: max(0, $0.count)) }
    }
}
