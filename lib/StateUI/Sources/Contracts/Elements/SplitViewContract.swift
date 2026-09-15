// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A page holding two: a sidebar at the side and the page beside it.
public enum SplitViewContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "SplitView"

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// A split view carries values, and is shown as a page with a title and an
    /// icon.
    public static let tiers: [any Contract.Type] = [PropertyContainerContract.self, PageElementContract.self]

    /// Whether the sidebar is showing.
    public static let isSidebarVisible = ElementProperty<Self, Bool>("isSidebarVisible", layer: .native)

    /// The reader showed or hid the sidebar, to the value it carries.
    public static let isSidebarVisibleChanged = ElementEvent<Self, Bool>(
        "isSidebarVisibleChanged", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [isSidebarVisible, isSidebarVisibleChanged]
}
