// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The platform's own collection of items: StateUI says which items there
/// are, in order, and builds the one the platform asks for; the platform
/// scrolls them, holds each in a cell it reuses, lets the user choose and
/// open one, and tells assistive technology about them.
public enum ItemsViewContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ItemsView"

    /// Every host shows it with its platform's own collection.
    public static let layer: ElementLayer = .native

    /// A collection is a view.
    public static let tiers: [any Contract.Type] = [ViewContract.self]

    /// Every item, header and footer it shows, by identity, in order.
    public static let items = ElementProperty<Self, ItemsEntries>("items", layer: .native, travels: false)

    /// Down, across, or in columns.
    public static let itemsLayout = ElementProperty<Self, ItemsLayout>("itemsLayout", layer: .native, travels: false)

    /// How many items the user can choose.
    public static let selectionMode = ElementProperty<Self, SelectionMode>(
        "selectionMode", layer: .native, travels: false)

    /// The chosen items' identities, in the order they show.
    public static let selectedItems = ElementProperty<Self, [String]>(
        "selectedItems", layer: .native, travels: false)

    /// The user chose items or let them go: every chosen identity, in the order
    /// they show.
    public static let selectionChanged = ElementEvent<Self, [String]>("selectionChanged", layer: .native)

    /// The user opened an item - a tap on a phone, a double-click or Return on a
    /// desktop - naming its identity.
    public static let itemActivated = ElementEvent<Self, String>("itemActivated", layer: .adaptive)

    /// How many items may still follow the last one in view when `endReached`
    /// is raised.
    public static let endReachedWithin = ElementProperty<Self, Int>(
        "endReachedWithin", layer: .native, travels: false)

    /// The user scrolled within `endReachedWithin` items of the end.
    public static let endReached = ElementEvent<Self, Void>("endReached", layer: .native)

    /// The identities the host now holds in its cells, whose subtrees it
    /// needs built.
    public static let realizedChanged = ElementEvent<Self, [String]>("realizedChanged", layer: .structure)

    /// Scrolls until the item of an identity stands where the anchor says, as
    /// the platform scrolls.
    public static let scrollTo = ElementAct<Self, (String, ScrollAnchor), Void>("scrollTo")

    /// The element's own members.
    public static let members: [any ContractMember] = [
        items, itemsLayout, selectionMode, selectedItems, selectionChanged, itemActivated, endReachedWithin,
        endReached, realizedChanged, scrollTo,
    ]
}
