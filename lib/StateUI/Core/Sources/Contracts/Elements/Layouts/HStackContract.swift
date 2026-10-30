// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Stacks its children left to right, each as wide as it asks to be.
public enum HStackContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "HStack"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A row is a stack.
    public static let tiers: [any Contract.Type] = [StackContract.self]

    /// The gap between one line and the next of a row that wraps, in device units.
    public static let rowSpacing = ElementProperty<Self, Double>("rowSpacing", layer: .stateUI, moves: .spacing)

    /// Whether the row goes on onto a further line where its room ends, rather than standing on one line.
    public static let wraps = ElementProperty<Self, Bool>("wraps", layer: .stateUI)

    /// The element's own members.
    public static let members: [any ContractMember] = [rowSpacing, wraps]
}
