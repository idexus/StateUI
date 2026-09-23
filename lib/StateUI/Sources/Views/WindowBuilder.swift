// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Builds the one window a scene's `main:` or a group's closure answers - an
/// `if` choosing between two being the one thing it adds to a plain return.
@resultBuilder
public enum WindowBuilder {
    /// A window written as a statement.
    public static func buildExpression(_ window: Window) -> Window { window }

    /// The one window the closure holds.
    public static func buildBlock(_ window: Window) -> Window { window }

    /// The `if` branch of an if/else.
    public static func buildEither(first window: Window) -> Window { window }

    /// The `else` branch.
    public static func buildEither(second window: Window) -> Window { window }

    /// What an `if #available(…)` block builds.
    public static func buildLimitedAvailability(_ window: Window) -> Window { window }
}
