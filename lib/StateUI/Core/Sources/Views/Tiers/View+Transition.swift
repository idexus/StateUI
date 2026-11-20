// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ViewProperties {
    /// How the view comes as the tree gains it, and goes as the tree drops it: from the transition's entry effect
    /// to how it stands, and from there to its exit effect, under its own motion - `.motion(_:)` - else the
    /// application's. The entry takes the place of the fade a view joining a standing layout comes with.
    ///
    ///     if showsNote {
    ///         Note().transition(.symmetric(.opacity.combined(with: .translation(y: 12))))
    ///     }
    ///
    /// A view enters as it joins what already stands; `initialAppearance(true)` enters as it first appears with
    /// what holds it too. Given to a view already standing, a transition moves nothing. A view the tree drops is
    /// the application's no more at once - it hears and tells nothing - and is drawn until its exit lands where
    /// the host keeps a view as it leaves; elsewhere it goes at once. Hiding a view with `isVisible(_:)` keeps it
    /// and its state, and is no leaving.
    public func transition(_ transition: Transition) -> Modified { setValue(ViewContract.transition, transition) }
}
