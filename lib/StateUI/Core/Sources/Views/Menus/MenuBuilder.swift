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
/// An `if`, an `if/else` and an array of items work in one, and a plain `for`
/// does not. An entry is matched by its `.id()` and otherwise by its position,
/// so an entry beside an `if`, and each of a list of entries that changes,
/// wants an id.
@resultBuilder
@MainActor
public enum MenuBuilder {
    /// An entry written as a statement.
    public static func buildExpression(_ expression: MenuItem) -> MenuEntries {
        MenuEntries([expression.node])
    }

    /// A menu opening one level down.
    public static func buildExpression(_ expression: Menu) -> MenuEntries {
        MenuEntries([expression.node])
    }

    /// A line between entries.
    public static func buildExpression(_ expression: MenuSeparator) -> MenuEntries {
        MenuEntries([expression.node])
    }

    /// Several entries, from something that already produced a list.
    public static func buildExpression(_ expression: [MenuItem]) -> MenuEntries {
        MenuEntries(expression.map(\.node))
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: MenuEntries...) -> MenuEntries {
        MenuEntries(components.flatMap(\.nodes))
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: MenuEntries?) -> MenuEntries {
        component ?? MenuEntries([])
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: MenuEntries) -> MenuEntries {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: MenuEntries) -> MenuEntries {
        component
    }
}

/// The entries a `MenuBuilder` collected, in the order they were written - what a menu, a context menu and a
/// button's menu hold.
@MainActor
public struct MenuEntries {
    /// The entries' nodes, in order.
    let nodes: [Node]

    init(_ nodes: [Node]) {
        self.nodes = nodes
    }
}
