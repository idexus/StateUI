// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the markers of a map written as consecutive statements.
///
///     Map(region: MapRegion(center: Location(latitude: 52.23, longitude: 21.01), radiusMeters: 2_000)).markers {
///         Marker(at: Location(latitude: 52.2479, longitude: 21.0155)).label("Royal Castle")
///
///         places.map { Marker(at: $0.location).label($0.name) }
///     }
///
/// An `if`, an `if/else` and an array of markers work in one, and a plain `for`
/// does not. A marker is matched by its `.id`, or else by its position among
/// the map's markers.
@resultBuilder
public enum MarkerBuilder {
    /// A single marker written as a statement.
    public static func buildExpression(_ expression: Marker) -> [Marker] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [Marker]) -> [Marker] {
        expression
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: [Marker]...) -> [Marker] {
        components.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: [Marker]?) -> [Marker] {
        component ?? []
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: [Marker]) -> [Marker] {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: [Marker]) -> [Marker] {
        component
    }
}
