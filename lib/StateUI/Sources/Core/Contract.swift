// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// What an element is, declared once: every node type has one contract naming its
// node type and every member with the type of its value. Swift writes through the
// members, and a host realizes the contract member by member.
// Design: docs/design/core/contracts.md#members-are-written-with-their-contract

/// A named set of members: the contract of one node type, or a tier - members
/// many elements wear.
///
/// Declared as an enum, which holds the members and is never made:
///
///     public enum FontElementContract: Contract {
///         public static let name = "FontElement"
///         public static let fontSize = ElementProperty<Self, Double>("fontSize", layer: .native)
///         public static let members: [any ContractMember] = [fontSize]
///     }
public protocol Contract: Sendable {
    /// What the contract is called: the node type's name for an element, the
    /// tier's own for a tier.
    static var name: String { get }

    /// The tiers this contract wears. Their members are its members too, and so
    /// are the members of the tiers they wear.
    static var tiers: [any Contract.Type] { get }

    /// The members declared here, in the order the documentation lists them.
    static var members: [any ContractMember] { get }
}

extension Contract {
    /// Nothing worn, unless the contract says.
    public static var tiers: [any Contract.Type] { [] }

    /// This contract and every tier it wears, each once, nearest first.
    static var worn: [any Contract.Type] {
        var seen: Set<ObjectIdentifier> = []
        var order: [any Contract.Type] = []

        func visit(_ contract: any Contract.Type) {
            guard seen.insert(ObjectIdentifier(contract)).inserted else { return }

            order.append(contract)

            for tier in contract.tiers {
                visit(tier)
            }
        }

        visit(Self.self)
        return order
    }
}
