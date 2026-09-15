// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// Stacks its children top to bottom, each as tall as it asks to be.
public enum VStackContract: ElementContract {
    /// The node type the contract declares.
    public static let nodeType: NodeType = "VStack"

    /// Every base host presents it with its native control.
    public static let layer: ElementLayer = .native

    /// A column is a stack.
    public static let tiers: [any Contract.Type] = [StackBaseContract.self]

    /// The element's own members.
    public static let members: [any ContractMember] = []
}
