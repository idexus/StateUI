// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A page showing several pages, one at a time, with a bar to choose between
/// them.
public enum TabbedViewContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "TabbedView"

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// Tabs have a bar, and are shown as a page with a title and an icon.
    public static let tiers: [any Contract.Type] = [BarElementContract.self, PageElementContract.self]

    /// Which tab is showing, counted from zero.
    public static let currentPage = ElementProperty<Self, Int>(
        "currentPage", layer: .structure, travels: false, cleared: false)

    /// The user chose another tab, the one it carries.
    public static let currentPageChanged = ElementEvent<Self, Int>("currentPageChanged", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [currentPage, currentPageChanged]
}
