// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ViewProperties {
    /// How the view comes onto the place its layout gives it: a body following its place lags behind it while the
    /// place moves and settles back onto it, one answering a change comes onto a new place on its spring, and
    /// `.none` stands at its place at once. It wins over what the layout says for every child
    /// (`layoutBodies(_:)`).
    ///
    ///     CardFace(card).layoutBody(.followsLayout(response: .milliseconds(420), damping: 0.6))
    ///
    /// It is the view's as a child of a stack, a grid, a ZStack or a motion layout.
    public func layoutBody(_ body: LayoutBody) -> Modified { setValue(ViewContract.layoutBody, body) }
}
