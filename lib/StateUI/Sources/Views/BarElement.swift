// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The bar a page ARRANGEMENT draws over its pages.
//
// Its own file rather than a block in Elements.swift, and the reason is a rule
// two tests keep: Elements.swift is the tier every VIEW shares, exactly, and
// `testTheSharedTierIsCoveredOnce` compares the properties declared there
// against the shared set. A bar is not a view's - it belongs to whatever
// arranges pages - so it is a tier of its own, beside them rather than among
// them.

/// The bar over a stack or a set of tabs.
///
/// They belong to the ARRANGEMENT rather than to a page on it: the bar looks
/// the same whichever page is showing. What one PAGE asks of the bar - to be
/// hidden or to carry a view instead of its title is written on that page's
/// `PageSession`.
///
/// Declared here rather than on `NavigationPage` for the reason every tier in
/// this library exists: `TabbedPage` carries the same three, and a copy on each
/// would be two places to fix one thing.
public protocol BarElement: PropertyContainer {}

extension BarElement {
    /// What the bar is painted, in one flat colour.
    ///
    ///     NavigationPage($path) {
    ///         HomePage()
    ///     } destination: { route in
    ///         DetailPage(route)
    ///     }
    ///     .barBackgroundColor(.cornflowerBlue)
    ///     .barTextColor(.white)
    ///
    /// Write this or `barBackground`, not both. A brush takes precedence when
    /// both are present.
    public func barBackgroundColor(_ value: Color) -> Modified {
        setValue(.barBackgroundColor, value.propValue)
    }

    /// What the bar is painted, where one flat colour will not do.
    ///
    ///     TabbedPage(Tab.allCases) { tab in
    ///         page(for: tab)
    ///     }
    ///     .barBackground(.linearGradient([
    ///         GradientStop(.cornflowerBlue, 0),
    ///         GradientStop(.indigo, 1),
    ///     ]))
    public func barBackground(_ value: Brush) -> Modified {
        setValue(.barBackground, value.propValue)
    }

    /// The colour of the bar's foreground content, including its title and
    /// navigation affordances.
    public func barTextColor(_ value: Color) -> Modified {
        setValue(.barTextColor, value.propValue)
    }
}
