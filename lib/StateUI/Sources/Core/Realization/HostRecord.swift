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
    }

    /// The element, or the tier, the member is judged on.
    public let owner: String

    /// The member.
    public let member: String

    /// What the record says of it.
    public let judgement: Judgement

    /// `member` of `owner`, judged as `judgement` says.
    public init(owner: String, member: String, judgement: Judgement) {
        self.owner = owner
        self.member = member
        self.judgement = judgement
    }

    /// `member` of `owner`, realized in full.
    public static func complete(_ owner: String, _ member: String) -> HostRecord {
        HostRecord(owner: owner, member: member, judgement: .complete)
    }

    /// `member` of `owner`, realized in part: `missing` says what is not.
    public static func partial(_ owner: String, _ member: String, missing: String) -> HostRecord {
        HostRecord(owner: owner, member: member, judgement: .partial(missing: missing))
    }

    /// `member` of `owner`, not planned for the host's family: `reason` says why.
    public static func notPlanned(_ owner: String, _ member: String, reason: String) -> HostRecord {
        HostRecord(owner: owner, member: member, judgement: .notPlanned(reason: reason))
    }
}
