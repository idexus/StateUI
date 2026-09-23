// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Collects the styles written in a `StyleSheet`'s closure; `if`, `else` and
/// `for` all work, so a sheet can answer a platform or a form factor.
@resultBuilder
public enum StyleBuilder {
    /// One style, whatever its target.
    public static func buildExpression<Target: StyleTarget>(_ style: Style<Target>) -> [AnyStyle] {
        [style.erased]
    }

    /// A group of them, already erased.
    public static func buildExpression(_ styles: [AnyStyle]) -> [AnyStyle] { styles }

    /// The statements of the closure, in order.
    public static func buildBlock(_ parts: [AnyStyle]...) -> [AnyStyle] { parts.flatMap { $0 } }

    /// An `if` with no `else`.
    public static func buildOptional(_ part: [AnyStyle]?) -> [AnyStyle] { part ?? [] }

    /// The `if` branch.
    public static func buildEither(first: [AnyStyle]) -> [AnyStyle] { first }

    /// The `else` branch.
    public static func buildEither(second: [AnyStyle]) -> [AnyStyle] { second }

    /// A `for` loop's turns.
    public static func buildArray(_ parts: [[AnyStyle]]) -> [AnyStyle] { parts.flatMap { $0 } }
}
