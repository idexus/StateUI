// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A view the platform shows in a popover by the view it is declared on, while a state says so.
public enum PopoverContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Popover"

    /// Every base host presents it with its native popover.
    public static let layer: ElementLayer = .native

    /// The tiers it wears.
    public static let tiers: [any Tier.Type] = [PresentedElementContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
