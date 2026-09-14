// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// The bar a page arrangement draws over its pages.
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
/// The shared capability is one optional flat background. Foreground content
/// differs by arrangement: a navigation bar has authored title and action
/// tint, while a native tab selector owns its selected and unselected states.
public protocol BarElement: PropertyContainer {}

extension BarElement {
    /// What the bar is painted, in one flat colour.
    ///
    ///     NavigationStack($path) {
    ///         HomePage()
    ///     } destination: { route in
    ///         DetailPage(route)
    ///     }
    ///     .barBackgroundColor(.cornflowerBlue)
    ///
    /// Leave it unwritten to retain the native material and appearance.
    public func barBackgroundColor(_ value: Color) -> Modified {
        setValue(.barBackgroundColor, value.propValue)
    }
}
