// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ViewProperties {
    /// How the view moves as a body of its motion layout's world, where it is one of the layout's views: a body
    /// following its place lags behind it while the run moves and settles back onto it.
    ///
    ///     CardFace(card).layoutBody(.followsLayout(.spring(response: .milliseconds(420), damping: 0.6)))
    ///
    /// A view of no motion layout moves by no world: there it changes nothing.
    public func layoutBody(_ body: LayoutBody) -> Modified { setValue(ViewContract.layoutBody, body) }

    /// The view follows its place in its motion layout on `spring` - the body `.layoutBody(.followsLayout(spring))`
    /// says: it lags behind its place while the run moves and settles back onto it.
    ///
    ///     CardFace(card).followsLayout(.spring(response: .milliseconds(420), damping: 0.55))
    ///
    /// A view of no motion layout moves by no world: there it changes nothing.
    public func followsLayout(_ spring: Motion) -> Modified { layoutBody(.followsLayout(spring)) }
}
