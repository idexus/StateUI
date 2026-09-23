// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the instructions written as consecutive statements into a drawing
/// - what a `Canvas`'s closure is built with.
///
/// Unlike `ViewBuilder`, this one has a `buildArray`, so a plain `for` loop
/// inside a drawing compiles: a chart draws a bar per value that way.
@resultBuilder
public enum DrawingBuilder {
    /// A single instruction written as a statement.
    public static func buildExpression(_ expression: DrawCommand) -> [DrawCommand] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [DrawCommand]) -> [DrawCommand] {
        expression
    }

    /// The statements of the closure, in the order they are written - which is
    /// the order the canvas draws them in.
    public static func buildBlock(_ components: [DrawCommand]...) -> [DrawCommand] {
        components.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: [DrawCommand]?) -> [DrawCommand] {
        component ?? []
    }

    /// Both branches of an if/else.
    public static func buildEither(first component: [DrawCommand]) -> [DrawCommand] {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: [DrawCommand]) -> [DrawCommand] {
        component
    }

    /// A `for` loop - which is how a chart draws a bar per value.
    public static func buildArray(_ components: [[DrawCommand]]) -> [DrawCommand] {
        components.flatMap { $0 }
    }
}
