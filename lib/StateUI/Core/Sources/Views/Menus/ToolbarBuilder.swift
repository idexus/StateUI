// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the items of a toolbar group written as consecutive statements.
///
///     .toolbar {
///         ToolbarItem("Add").onClicked { add() }
///
///         if canShare {
///             ToolbarItem("Share").onClicked { share() }
///         }
///     }
///
/// An `if`, an `if/else` and an array of items work in one, and a plain `for`
/// does not. An item is matched by its `.id()` and otherwise by its position,
/// so an item beside an `if` wants an id.
@resultBuilder
public enum ToolbarBuilder {
    /// A single item written as a statement.
    public static func buildExpression(_ expression: ToolbarItem) -> [ToolbarItem] {
        [expression]
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [ToolbarItem]) -> [ToolbarItem] {
        expression
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: [ToolbarItem]...) -> [ToolbarItem] {
        components.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: [ToolbarItem]?) -> [ToolbarItem] {
        component ?? []
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: [ToolbarItem]) -> [ToolbarItem] {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: [ToolbarItem]) -> [ToolbarItem] {
        component
    }
}
