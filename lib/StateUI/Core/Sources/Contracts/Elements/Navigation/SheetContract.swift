// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A page the platform presents over the window in its native sheet while a state says so, declared by the view
/// presenting it: its child is the page, there while it shows.
public enum SheetContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "Sheet"

    /// Every base host presents it by its platform's conventions, keeping StateUI's state contract.
    public static let layer: ElementLayer = .adaptive

    /// Whether the sheet shows: the application presents it, and the user's dismissal writes false.
    public static let isPresented = ElementProperty<Self, Bool>("isPresented", layer: .adaptive)

    /// The user dismissed the sheet - a swipe, Escape, the way back.
    public static let isPresentedChanged = ElementEvent<Self, Bool>("isPresentedChanged", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [isPresented, isPresentedChanged]
}
