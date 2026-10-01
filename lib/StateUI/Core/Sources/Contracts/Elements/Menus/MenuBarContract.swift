// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// The menus a page or an arrangement declares for the menu bar, joining the
/// menus of the same id declared around it.
public enum MenuBarContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "MenuBar"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// Where the declaration's menus and sections stand among the others: lower earlier.
    public static let order = ElementProperty<Self, Int>("order", layer: .stateUI, travels: false, cleared: false)

    /// The element's own members.
    public static let members: [any ContractMember] = [order]
}
