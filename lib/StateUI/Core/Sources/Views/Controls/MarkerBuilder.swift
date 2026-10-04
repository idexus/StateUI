// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the markers of a map written as consecutive statements.
///
///     Map(latitude: 52.23, longitude: 21.01, radiusMeters: 2_000).markers {
///         Marker("Royal Castle").location(latitude: 52.2479, longitude: 21.0155)
///
///         places.map { Marker($0.name).location(latitude: $0.latitude, longitude: $0.longitude).id($0.id) }
///     }
///
/// An `if`, an `if/else` and an array of markers work in one, and a plain `for`
/// does not. A marker is matched by its `.id()` and otherwise by its position.
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
