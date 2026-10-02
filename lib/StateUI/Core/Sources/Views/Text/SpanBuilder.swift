// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the runs of a label's text written as consecutive statements.
///
///     Text().spans {
///         TextSpan("let ").textColor(.purple)
///
///         if showsName {
///             TextSpan(name).textColor(.steelBlue)
///         }
///
///         tokens.map { TextSpan($0.text).textColor($0.colour) }
///     }
///
/// An `if`, an `if/else` and an array of runs work in one, and a plain `for`
/// does not. A run is matched by its position.
@resultBuilder
public enum SpanBuilder {
    /// A single run written as a statement.
    public static func buildExpression(_ expression: TextSpan) -> [TextSpan] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [TextSpan]) -> [TextSpan] {
        expression
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: [TextSpan]...) -> [TextSpan] {
        components.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: [TextSpan]?) -> [TextSpan] {
        component ?? []
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: [TextSpan]) -> [TextSpan] {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: [TextSpan]) -> [TextSpan] {
        component
    }
}
