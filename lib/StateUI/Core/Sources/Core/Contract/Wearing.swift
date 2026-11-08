// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

// A member handed to an element whose contract does not take it, said once as the view is described.
// Design: docs/design/core/contracts.md#a-member-the-element-does-not-wear

/// What each element's contract takes: the members of the contracts it wears, each listed among its contract's
/// members. A member handed to an element otherwise is said once and reaches no host.
@_spi(Host) @MainActor public enum Wearing {
    /// Each element's declaration by its node type, as its first node was made.
    private static var declarations: [NodeType: any ElementContract.Type] = [:]

    /// The members judged so far, and whether the element takes each.
    private static var judged: [Judged: Bool] = [:]

    /// One member of one contract, handed to one element.
    private struct Judged: Hashable {
        let element: ObjectIdentifier
        let owner: ObjectIdentifier
        let member: KeyName
    }

    /// Whether the element of node type `type` wears `owner`; nil where no node of that type was made through
    /// its contract.
    public static func element(_ type: NodeType, wears owner: any Contract.Type) -> Bool? {
        declarations[type].map { $0.wears(owner) }
    }

    /// Notes the declaration a node was made through.
    static func declare(_ declaration: any ElementContract.Type) {
        if declarations[declaration.nodeType] == nil { declarations[declaration.nodeType] = declaration }
    }

    /// Whether `element` takes `member`: a contract it wears declares it among its members. Said once where it
    /// does not; an element made with no contract takes anything.
    @discardableResult
    static func takes<Member: KeyedMember>(_ element: (any ElementContract.Type)?, _ member: Member) -> Bool {
        takes(element, member, of: Member.Owner.self)
    }

    /// The judgment, one body for every member's type.
    /// Design: docs/design/platforms/web/runtime.md#the-modules-size
    private static func takes(
        _ element: (any ElementContract.Type)?, _ member: any KeyedMember, of owner: any Contract.Type
    ) -> Bool {
        guard let element else { return true }

        let key = Judged(element: ObjectIdentifier(element), owner: ObjectIdentifier(owner), member: member.memberKey)
        if let known = judged[key] { return known }

        let worn = element.wears(owner)
        let listed = owner.members.contains { ($0 as? any KeyedMember)?.memberKey == member.memberKey }
        if !worn {
            complain("\(element.name) was handed `\(owner.name).\(member.name)`, and \(element.name) wears no "
                + "\(owner.name): no host shows it there.")
        } else if !listed {
            complain("`\(owner.name).\(member.name)` is not among \(owner.name)'s members: no host shows it.")
        }
        judged[key] = worn && listed
        return worn && listed
    }
}

/// A member as the judgment reads it: by its key.
protocol KeyedMember: ContractMember {
    /// The key it crosses under.
    var memberKey: KeyName { get }
}

extension ElementProperty: KeyedMember {
    /// The key it crosses under.
    var memberKey: KeyName { token.key }
}

extension ElementEvent: KeyedMember {
    /// The key it crosses under.
    var memberKey: KeyName { token.key }
}

extension ElementAct: KeyedMember {
    /// The key it crosses under.
    var memberKey: KeyName { token.key }
}
