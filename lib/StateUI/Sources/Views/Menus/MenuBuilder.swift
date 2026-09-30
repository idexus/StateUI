// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the entries of a menu written as consecutive statements: a
/// `MenuItem`, a `Menu` opening one level down and a `MenuSeparator`.
///
///     Menu("View") {
///         MenuItem("Zoom in").onClicked { zoom(+1) }
///
///         if canReset {
///             MenuItem("Actual size").onClicked { zoom(0) }
///         }
///     }
///
/// An `if`, an `if/else` and a `ForEach` work in one, and a plain `for` does
/// not. An entry is matched by its `.id()` and otherwise by its position, so a
/// hand-written entry beside an `if` wants an id; `ForEach` gives its entries
/// their items' identities.
@resultBuilder
public enum MenuBuilder {
    /// An entry written as a statement.
    public static func buildExpression(_ expression: MenuItem) -> [Element] {
        [expression]
    }

    /// A menu opening one level down.
    public static func buildExpression(_ expression: Menu) -> [Element] {
        [expression]
    }

    /// A line between entries.
    public static func buildExpression(_ expression: MenuSeparator) -> [Element] {
        [expression]
    }

    /// Several entries, from something that already produced a list.
    public static func buildExpression(_ expression: [MenuItem]) -> [Element] {
        expression
    }

    /// A `ForEach`'s entries, each identified by its item.
    public static func buildExpression(_ expression: ForEach) -> [Element] {
        expression.elements
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: [Element]...) -> [Element] {
        components.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: [Element]?) -> [Element] {
        component ?? []
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: [Element]) -> [Element] {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: [Element]) -> [Element] {
        component
    }
}
