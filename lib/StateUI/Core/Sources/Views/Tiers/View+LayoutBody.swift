// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

extension ViewProperties {
    /// How the view comes onto the place its motion layout gives it, where it is one of the layout's views: a body
    /// following its place lags behind it while the run moves and settles back onto it, and `.none` stands at its
    /// place at once. It wins over what the layout says for every view (`layoutBodies(_:)`).
    ///
    ///     CardFace(card).layoutBody(.followsLayout(Spring(response: .milliseconds(420), damping: 0.6)))
    ///
    /// A view of no motion layout is placed by none: there it changes nothing.
    public func layoutBody(_ body: LayoutBody) -> Modified { setValue(ViewContract.layoutBody, body) }
}
