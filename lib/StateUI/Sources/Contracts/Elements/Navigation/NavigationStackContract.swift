// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A page holding a native stack of pages, with a bar and a back affordance.
public enum NavigationStackContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "NavigationStack"

    /// Every base host presents it by its platform's conventions, keeping
    /// StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// A stack has a bar, and is shown as a page with a title and an icon.
    public static let tiers: [any Contract.Type] = [BarElementContract.self, PageElementContract.self]

    /// The colour the bar draws on its background: the title and the native
    /// affordances.
    public static let barForegroundColor = ElementProperty<Self, Color>(
        "barForegroundColor", layer: .adaptive)

    /// The user went back natively, leaving this many pages above the root.
    public static let popped = ElementEvent<Self, Int>("popped", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [barForegroundColor, popped]
}
