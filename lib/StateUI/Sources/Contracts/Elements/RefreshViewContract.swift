// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Pull down on what is inside it to ask for it again.
public enum RefreshViewContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "RefreshView"

    /// StateUI composes it from smaller primitives before a host receives the
    /// tree.
    public static let layer: ElementLayer = .stateUI

    /// A refreshing view is a view, tinted.
    public static let tiers: [any Contract.Type] = [ViewContract.self, TintElementContract.self]

    /// Whether a pull does anything at all.
    public static let isRefreshEnabled = ElementProperty<Self, Bool>("isRefreshEnabled", layer: .stateUI)

    /// Whether the spinner is showing.
    public static let isRefreshing = ElementProperty<Self, Bool>("isRefreshing", layer: .stateUI)

    /// The platform showed or hid the spinner, to the value it carries.
    public static let isRefreshingChanged = ElementEvent<Self, Bool>("isRefreshingChanged", layer: .stateUI)

    /// The reader pulled.
    public static let refreshRequested = ElementEvent<Self, Void>("refreshRequested", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        isRefreshEnabled, isRefreshing, isRefreshingChanged, refreshRequested,
    ]
}
