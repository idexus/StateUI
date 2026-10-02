// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// A group of actions a page or an arrangement declares for its bar: one shared background where the platform draws
/// one, joined by the groups of the same id declared further in.
public enum ToolbarItemGroupContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "ToolbarItemGroup"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// Where the group stands among the others at its edge: lower earlier in reading order.
    public static let order = ElementProperty<Self, Int>("order", layer: .stateUI, travels: false, cleared: false)

    /// The edge of the bar the group stands at.
    public static let side = ElementProperty<Self, ToolbarSide>(
        "side", layer: .adaptive, travels: false, cleared: false)

    /// The element's own members.
    public static let members: [any ContractMember] = [order, side]
}
