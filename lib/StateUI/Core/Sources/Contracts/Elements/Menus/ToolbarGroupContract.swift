// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A group of actions a page or a split view declares for its bar - one shared background where the platform draws
/// one - and where it stands: a lone item stands in a group of its own.
public enum ToolbarGroupContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ToolbarGroup"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// Where its host draws the bar itself, the background its items share is the application's to say.
    public static let tiers: [any Contract.Type] = [
        BarItemElementContract.self, BorderElementContract.self, PaddingElementContract.self,
    ]

    /// Whether it hides with its split view's sidebar rather than move over the detail while the sidebar is not shown.
    public static let hidesWithSidebar = ElementProperty<Self, Bool>(
        "hidesWithSidebar", layer: .stateUI, travels: false, cleared: false, unsaid: false)

    /// Whether its items can be chosen: false leaves every one out of reach, as a disabled view does what it holds.
    public static let isEnabled = ElementProperty<Self, Bool>("isEnabled", layer: .native)

    /// Where the group stands among the others at its edge: lower earlier in reading order.
    public static let order = ElementProperty<Self, Int>(
        "order", layer: .stateUI, travels: false, cleared: false, unsaid: 0)

    /// The part of its split view's bar it stands in; unsaid, the part of the page or split view declaring it.
    public static let part = ElementProperty<Self, ToolbarPart>("part", layer: .stateUI, travels: false, cleared: false)

    /// Whether it is the group of its own a lone item stands in, not one its author declared: written by StateUI
    /// alone, read by a host drawing a group a background, which draws none behind a lone item.
    public static let standsAlone = ElementProperty<Self, Bool>(
        "standsAlone", layer: .stateUI, travels: false, cleared: false, unsaid: false)

    /// The room between its items, where its host draws the bar itself.
    public static let spacing = ElementProperty<Self, Double>("spacing", layer: .adaptive, moves: .spacing)

    /// Where on the bar it stands: at an edge, or behind the overflow menu.
    public static let position = ElementProperty<Self, ToolbarPosition>(
        "position", layer: .adaptive, travels: false, cleared: false, unsaid: .end)

    /// The element's own members.
    public static let members: [any ContractMember] = [
        hidesWithSidebar, isEnabled, order, part, position, spacing, standsAlone,
    ]
}
