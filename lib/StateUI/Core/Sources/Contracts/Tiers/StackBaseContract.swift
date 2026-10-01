// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What both stacks have: the space between their children.
public enum StackBaseContract: Contract {
    /// The tier's name.
    public static let name = "StackBase"

    /// A stack is a layout.
    public static let tiers: [any Contract.Type] = [LayoutContract.self]

    /// The space between one child and the next.
    public static let spacing = ElementProperty<Self, Double>("spacing", layer: .native, moves: .spacing)

    /// The tier's own members.
    public static let members: [any ContractMember] = [spacing]
}
