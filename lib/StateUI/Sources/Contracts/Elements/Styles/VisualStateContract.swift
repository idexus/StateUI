// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One state a control can be in, and the values it sets there.
public enum VisualStateContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "VisualState"

    /// It carries structure, not a platform control of its own.
    public static let layer: ElementLayer = .structure

    /// The group the state belongs to: a control is in one state of each group.
    public static let group = ElementProperty<Self, Name>("group", layer: .structure)

    /// The state's name, matched exactly.
    public static let name = ElementProperty<Self, Name>("name", layer: .structure)

    /// The element's own members.
    public static let members: [any ContractMember] = [group, name]
}
