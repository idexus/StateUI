// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ViewProperties {
    /// How the view comes as the tree gains it: from the transition's entry effect to how it stands, under its own
    /// motion - `.motion(_:)` - else the application's. It takes the place of the fade a view joining a standing
    /// layout comes with.
    ///
    ///     if showsNote {
    ///         Note().transition(.symmetric(.opacity.combined(with: .translation(y: 12))))
    ///     }
    ///
    /// A view enters as it joins what already stands; `initialAppearance(true)` enters as it first appears with
    /// what holds it too. Given to a view already standing, a transition moves nothing. A view the tree drops goes
    /// at once. Hiding a view with `isVisible(_:)` keeps it and its state, and is no leaving.
    public func transition(_ transition: Transition) -> Modified { setValue(ViewContract.transition, transition) }
}
