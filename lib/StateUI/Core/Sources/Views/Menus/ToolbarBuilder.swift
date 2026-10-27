// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a `.toolbar { }` declares: its groups, a lone item standing in one of its own.
public struct ToolbarContent {
    /// The groups, in the order declared.
    let groups: [Node]
}

/// Collects a toolbar's items and groups written as consecutive statements.
///
///     .toolbar {
///         ToolbarButton("Add").onClicked { add() }
///
///         if canShare {
///             ToolbarButton("Share").onClicked { share() }
///         }
///     }
///
/// An `if`, an `if/else` and an array work in one, and a plain `for` does
/// not. An item is matched by its `.id()` and otherwise by its position, so
/// an item beside an `if` wants an id.
@resultBuilder @MainActor
public enum ToolbarBuilder {
    /// An item standing alone.
    public static func buildExpression(_ expression: some ToolbarItem) -> ToolbarContent {
        ToolbarContent(groups: [expression.standingAlone])
    }

    /// Items, each standing alone.
    public static func buildExpression(_ expression: [some ToolbarItem]) -> ToolbarContent {
        ToolbarContent(groups: expression.map(\.standingAlone))
    }

    /// A group.
    public static func buildExpression(_ expression: ToolbarGroup) -> ToolbarContent {
        ToolbarContent(groups: [expression.node])
    }

    /// Groups, in order.
    public static func buildExpression(_ expression: [ToolbarGroup]) -> ToolbarContent {
        ToolbarContent(groups: expression.map(\.node))
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: ToolbarContent...) -> ToolbarContent {
        ToolbarContent(groups: components.flatMap(\.groups))
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: ToolbarContent?) -> ToolbarContent {
        component ?? ToolbarContent(groups: [])
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: ToolbarContent) -> ToolbarContent {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: ToolbarContent) -> ToolbarContent {
        component
    }
}

/// What a `ToolbarGroup` holds: its items, in reading order.
public struct ToolbarGroupContent {
    /// The items' nodes.
    let items: [Node]
}

/// Collects a `ToolbarGroup`'s items: items only, so a group holds no group.
@resultBuilder @MainActor
public enum ToolbarGroupBuilder {
    /// A single item written as a statement.
    public static func buildExpression(_ expression: some ToolbarItem) -> ToolbarGroupContent {
        ToolbarGroupContent(items: [expression.held])
    }

    /// Several, from something that already produced a list.
    public static func buildExpression(_ expression: [some ToolbarItem]) -> ToolbarGroupContent {
        ToolbarGroupContent(items: expression.map(\.held))
    }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ components: ToolbarGroupContent...) -> ToolbarGroupContent {
        ToolbarGroupContent(items: components.flatMap(\.items))
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ component: ToolbarGroupContent?) -> ToolbarGroupContent {
        component ?? ToolbarGroupContent(items: [])
    }

    /// The `if` branch of an if/else.
    public static func buildEither(first component: ToolbarGroupContent) -> ToolbarGroupContent {
        component
    }

    /// The `else` branch.
    public static func buildEither(second component: ToolbarGroupContent) -> ToolbarGroupContent {
        component
    }
}
