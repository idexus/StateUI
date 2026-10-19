// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// One member judged on a host by hand: on an element, or on a tier for every element wearing it.
/// Design: docs/design/contracts/dictionary.md#marks
@_spi(Host) public struct HostRecord: Hashable, Sendable {
    /// What a record says of its member.
    public enum Judgement: Hashable, Sendable {
        /// Realized in full.
        case complete
        /// Realized in part; what is missing.
        case partial(missing: String)
        /// Not planned for the host's family, which meets the contract there; why.
        case notPlanned(reason: String)
        /// Not realized on this element, though a tier's record reaches it; why.
        case unrealized(why: String)

        /// Left to the application, which registers its own control for the element with the host.
        case byApplication
    }

    /// The element, or the tier, the member is judged on.
    public let owner: String

    /// The member.
    public let member: String

    /// What the record says of it.
    public let judgement: Judgement

    /// `member` of `owner`, judged as `judgement` says: a record the register derives from what a runtime realizes.
    init(owner: String, member: String, judgement: Judgement) {
        self.owner = owner
        self.member = member
        self.judgement = judgement
    }

    /// `member`, realized in full: on every element wearing its contract, or on `element` alone.
    public static func complete<Member: ContractMember>(_ member: Member, on element: (any Contract.Type)? = nil) -> HostRecord {
        HostRecord(owner: (element ?? Member.Owner.self).name, member: member.name, judgement: .complete)
    }

    /// `member`, realized in part - on every element wearing its contract, or on `element` alone: `missing` says what
    /// is not.
    public static func partial<Member: ContractMember>(
        _ member: Member, on element: (any Contract.Type)? = nil, missing: String
    ) -> HostRecord {
        HostRecord(owner: (element ?? Member.Owner.self).name, member: member.name, judgement: .partial(missing: missing))
    }

    /// `member`, not planned for the host's family - on every element wearing its contract, or on `element` alone:
    /// `reason` says why.
    public static func notPlanned<Member: ContractMember>(
        _ member: Member, on element: (any Contract.Type)? = nil, reason: String
    ) -> HostRecord {
        HostRecord(owner: (element ?? Member.Owner.self).name, member: member.name, judgement: .notPlanned(reason: reason))
    }

    /// `member`, not realized on `element` though a tier's record reaches it: `why` says why.
    public static func unrealized<Member: ContractMember>(
        _ member: Member, on element: any ElementContract.Type, why: String
    ) -> HostRecord {
        HostRecord(owner: element.name, member: member.name, judgement: .unrealized(why: why))
    }
}
