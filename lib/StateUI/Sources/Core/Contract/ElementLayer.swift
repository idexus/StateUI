// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Which layer realizes an element or one of its members.
public enum ElementLayer: Sendable {
    /// Every base host presents it with its native toolkit.
    case native

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    case adaptive

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    case stateUI

    /// It carries structure or protocol data rather than configuring a visual
    /// platform object.
    case structure

    /// An optional provider supplies it: a package, or the application that
    /// registers it with its hosts.
    case provider
}
