// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A page the platform presents over the window in its native sheet while a state says so, declared by the view
/// presenting it: its child is the page, there while it shows.
public enum SheetContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Sheet"

    /// Every base host presents it by its platform's conventions, keeping StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// The tiers it wears.
    public static let tiers: [any Tier.Type] = [PresentedElementContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
