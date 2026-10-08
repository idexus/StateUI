// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A page holding two: a sidebar at the side and the page beside it.
public enum SplitViewContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "SplitView"

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// A split view declares the bar over what it shows, is shown as a page
    /// with a title and an icon, and automation finds it by its name.
    public static let tiers: [any Contract.Type] = [
        BarElementContract.self, PageElementContract.self, PropertyContainerContract.self,
    ]

    /// Whether the sidebar is showing.
    public static let showsSidebar = ElementProperty<Self, Bool>("showsSidebar", layer: .native)

    /// The user showed or hid the sidebar, to the value it carries.
    public static let showsSidebarChanged = ElementEvent<Self, Bool>(
        "showsSidebarChanged", layer: .adaptive)

    /// What the sidebar stands on beside the detail; unwritten, the
    /// platform's own there.
    public static let sidebarBackground = ElementProperty<Self, Material>("sidebarBackground", layer: .adaptive)

    /// What the sidebar stands on while it slides over the detail; unwritten,
    /// the platform's own surface there, never the window's.
    public static let flyoutBackground = ElementProperty<Self, Material>("flyoutBackground", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        showsSidebar, showsSidebarChanged, sidebarBackground, flyoutBackground,
    ]
}
