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

    /// Draws the view as one with the view of the same transition id that leaves as it comes, or comes as it leaves,
    /// in the same change - in another holder, or another kind of view: the one coming sets out from where the other
    /// is drawn, as fast as it moves, its corner too, and lands on its own place under its own motion. With no such
    /// view it comes and goes by its `transition(_:)`.
    ///
    ///     if let chosen {
    ///         Picture(chosen).transitionID(chosen.id)     // grows out of its thumbnail
    ///     } else {
    ///         HStack { ForEach(items, id: \.id) { Thumbnail($0).transitionID($0.id) } }
    ///     }
    ///
    /// The views of one transition id meet on their page, in the scope `transitionScope(_:)` names where one is
    /// named. One leaves and one comes: an id standing on more than one view there as the change runs makes nothing
    /// one, and is said once.
    ///
    /// - Parameter id: what the two views drawn as one share; any `Hashable`.
    public func transitionID(_ id: some Hashable) -> Modified {
        setValue(ViewContract.transitionID, Renderer.shared.sharedIdentities.number(for: AnyHashable(id)))
    }

    /// Where the view's transition id meets another: only views naming the same scope, and the same id, are drawn
    /// as one - so the parts of a component, its title and its picture, are named once for every card that holds
    /// one. A scope with no transition id makes the view one with nothing, and is said once.
    ///
    ///     Text(card.title).transitionID("title").transitionScope(card.id)
    ///
    /// - Parameter scope: where the view's transition id meets another; any `Hashable`.
    public func transitionScope(_ scope: some Hashable) -> Modified {
        setValue(ViewContract.transitionScope, Renderer.shared.sharedIdentities.number(for: AnyHashable(scope)))
    }
}
