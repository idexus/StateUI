// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A scrollable container.
public enum ScrollViewContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ScrollView"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A scroller is a view, padded around what it holds.
    public static let tiers: [any Contract.Type] = [ViewContract.self, PaddingElementContract.self]

    /// Whether the bar along the bottom is drawn.
    public static let horizontalScrollBarVisibility = ElementProperty<Self, ScrollBarVisibility>(
        "horizontalScrollBarVisibility", layer: .adaptive)

    /// Which way it scrolls.
    public static let orientation = ElementProperty<Self, ScrollOrientation>("orientation", layer: .native)

    /// Where the scroller stands, in device units from the content's top-left
    /// corner: one point of two lanes, so one journey makes a diagonal move
    /// arrive on both axes together.
    public static let scrollOffset = ElementProperty<Self, Point>(
        "scrollOffset", layer: .structure, travels: false)

    /// The scroller came to rest.
    public static let scrollStopped = ElementEvent<Self, Void>("scrollStopped", layer: .native)

    /// The scroller moved across, to the offset it carries.
    public static let scrollXChanged = ElementEvent<Self, Double>("scrollXChanged", layer: .native)

    /// The scroller moved down, to the offset it carries.
    public static let scrollYChanged = ElementEvent<Self, Double>("scrollYChanged", layer: .native)

    /// Whether the bar down the side is drawn.
    public static let verticalScrollBarVisibility = ElementProperty<Self, ScrollBarVisibility>(
        "verticalScrollBarVisibility", layer: .adaptive)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        horizontalScrollBarVisibility, orientation, scrollOffset, scrollStopped, scrollXChanged,
        scrollYChanged, verticalScrollBarVisibility,
    ]
}
