// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A fill as every host reads what the tree sends: nothing, one colour, or a gradient's stops over a geometry in
/// fractions of what it paints - its colours as the tree gives them, which a host turns into its toolkit's.
/// Design: docs/design/types/brushes.md#as-a-host-is-handed-it
@_spi(Host) public enum HostBrush: Equatable, Sendable {
    /// One stop of a gradient: where it stands, 0 to 1, and its colour.
    public struct Stop: Equatable, Sendable {
        /// Where the stop stands along the gradient, 0 to 1.
        public let offset: Double

        /// Its colour, as the tree gives it.
        public let color: HostValue
    }

    /// Nothing painted.
    case none

    /// One colour.
    case solid(HostValue)

    /// Colours along the line from one point to another.
    case linear(from: Point, to: Point, stops: [Stop])

    /// Colours out from a centre to a radius.
    case radial(center: Point, radius: Double, stops: [Stop])

    /// The brush the tree's `value` describes: a bare colour is one colour; a gradient's stops stand between 0
    /// and 1, its geometry what it gives - top to bottom, or from the middle to the edge, where it gives none.
    public init(_ value: HostValue?) {
        if let value, value.color != nil {
            self = .solid(value)
            return
        }
        guard let parts = value?.values, let kind = parts.first?.enumeration else {
            self = .none
            return
        }
        if kind == 1 {
            self = parts.count > 1 && parts[1].color != nil ? .solid(parts[1]) : .none
            return
        }

        var stops: [Stop] = []
        var index = 2
        while index + 1 < parts.count, let offset = parts[index].number, parts[index + 1].color != nil {
            stops.append(Stop(offset: min(max(offset, 0), 1), color: parts[index + 1]))
            index += 2
        }
        let given = parts.count > 1 ? parts[1].numbers ?? [] : []
        func at(_ index: Int, _ standing: Double) -> Double { index < given.count ? given[index] : standing }
        self = kind == 3
            ? .radial(center: Point(x: at(0, 0.5), y: at(1, 0.5)), radius: at(2, 0.5), stops: stops)
            : .linear(from: Point(x: at(0, 0), y: at(1, 0)), to: Point(x: at(2, 0), y: at(3, 1)), stops: stops)
    }

    /// The brush's colour, or its first stop's: what a line of one colour draws with it.
    public var firstColor: HostValue? {
        switch self {
        case .none: nil
        case .solid(let color): color
        case .linear(_, _, let stops), .radial(_, _, let stops): stops.first?.color
        }
    }
}
