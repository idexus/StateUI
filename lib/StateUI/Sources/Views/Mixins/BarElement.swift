// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The bar over a stack or a set of tabs. It belongs to the arrangement and
/// looks the same whichever page shows; what one page asks of the bar - to be
/// hidden, or to carry a view instead of its title - is written on its
/// `PageSession`.
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
        setValue(BarElementContract.barBackgroundColor, value)
    }
}
