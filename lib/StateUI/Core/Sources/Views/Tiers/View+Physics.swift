// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ViewProperties {
    /// How the view moves as a body of its motion layout's world, where it is one of the layout's views: a body
    /// following its place lags behind it while the run moves and settles back onto it.
    ///
    ///     CardFace(card).physicsBody(.followsLayout(.spring(response: .milliseconds(420), damping: 0.6)))
    ///
    /// A view of no motion layout moves by no world: there it changes nothing.
    public func physicsBody(_ body: PhysicsBody) -> Modified { setValue(ViewContract.physicsBody, body) }
}
