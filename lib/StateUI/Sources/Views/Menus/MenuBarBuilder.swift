// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the menus of a menu bar written as consecutive statements.
///
///     .menuBar {
///         Menu("File") { … }.id(StandardMenu.file)
///
///         if hasDocument {
///             Menu("Format") { … }
///         }
///     }
///
/// Only a `Menu` stands on a menu bar. An `if`, an `if/else` and an array of
/// menus work in one, and a plain `for` does not.
@resultBuilder
public enum MenuBarBuilder {
    /// A single menu written as a statement.
    public static func buildExpression(_ expression: Menu) -> [Menu] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [Menu]) -> [Menu] {
        expression
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: [Menu]...) -> [Menu] {
        components.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: [Menu]?) -> [Menu] {
        component ?? []
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: [Menu]) -> [Menu] {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: [Menu]) -> [Menu] {
        component
    }
}
