// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Builds a scene's groups - one per statement, and an `if` for a group only
/// some scenes declare.
@resultBuilder
public enum WindowGroupBuilder {
    /// A group written as a statement.
    public static func buildExpression(_ group: WindowGroup) -> [WindowGroup] { [group] }

    /// The statements of the closure, in the order they are written.
    public static func buildBlock(_ groups: [WindowGroup]...) -> [WindowGroup] {
        groups.flatMap { $0 }
    }

    /// An `if` without an `else`.
    public static func buildOptional(_ groups: [WindowGroup]?) -> [WindowGroup] { groups ?? [] }

    /// The `if` branch of an if/else.
    public static func buildEither(first groups: [WindowGroup]) -> [WindowGroup] { groups }

    /// The `else` branch.
    public static func buildEither(second groups: [WindowGroup]) -> [WindowGroup] { groups }

    /// What an `if #available(…)` block builds.
    public static func buildLimitedAvailability(_ groups: [WindowGroup]) -> [WindowGroup] {
        groups
    }
}
