// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// An element the user pulls to refresh what it shows - a scroller, a list.
public enum RefreshElementContract: Contract {
    /// The tier's name.
    public static let name = "RefreshElement"

    /// Whether the refresh is under way - its spinner showing: the user's pull sets it, and the application ends it.
    public static let isRefreshing = ElementProperty<Self, Bool>("isRefreshing", layer: .native)

    /// Whether the user can pull to refresh.
    public static let isRefreshEnabled = ElementProperty<Self, Bool>("isRefreshEnabled", layer: .native)

    /// The user pulled to refresh.
    public static let refreshRequested = ElementEvent<Self, Void>("refreshRequested", layer: .native)

    /// The tier's own members.
    public static let members: [any ContractMember] = [isRefreshEnabled, isRefreshing, refreshRequested]
}
