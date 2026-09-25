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

/// What a host realizes of the contracts, member by member: its judgements written by hand, then what its runtime
/// says it realizes. The one rule a host's column of the dictionary and a conformance case both read.
/// Design: docs/design/contracts/dictionary.md#marks
@_spi(Host) public struct HostMarks: Sendable {
    /// What a host realizes of one member of one element.
    public enum Mark: Equatable, Sendable {
        /// Realized in full.
        case complete
        /// Realized in part; what is missing.
        case partial(missing: String)
        /// Not planned for the host's family; why.
        case notPlanned(reason: String)
        /// Not realized, or not judged yet.
        case absent
    }

    /// Every record: the written ones first.
    public let records: [HostRecord]

    /// The elements the host realizes none of.
    public let unrealized: Set<String>

    /// The elements the host presents with no view of their own, which no tier's record reaches.
    public let viewless: Set<String>

    /// The elements the host's family will never have: each meets the contract there.
    public let notPlanned: Set<String>

    /// Marks from `records`, written before anything a runtime adds, and the elements realized none of, shown with
    /// no view, and not planned.
    public init(records: [HostRecord], unrealized: Set<String>, viewless: Set<String>, notPlanned: Set<String> = []) {
        self.records = records
        self.unrealized = unrealized
        self.viewless = viewless
        self.notPlanned = notPlanned
    }

    /// These marks with what the host's runtime realizes behind them. What is written comes first: a runtime says
    /// presence alone, where a written record may say what is missing, so a member the written half speaks for -
    /// on its owner, or on a tier the owner wears - is dropped from the runtime's records.
    public func and(_ runtime: [HostRecord]) -> HostMarks {
        let written = Set(records.map { "\($0.owner).\($0.member)" })
        let realized = runtime.filter { record in
            !written.contains("\(record.owner).\(record.member)")
                && !records.contains { $0.member == record.member && Self.wears(record.owner, $0.owner) }
        }
        return HostMarks(
            records: records + realized, unrealized: unrealized, viewless: viewless, notPlanned: notPlanned)
    }

    /// These marks with a host's declaration of what its runtime realizes behind them.
    public func and(_ declaration: HostDeclaration) -> HostMarks {
        and(Self.records(of: declaration))
    }

    /// What the host realizes of `member` on `element`: the element's own record, else the record of the tier the
    /// member comes from.
    public func mark(of member: String, on element: String, from tier: String?) -> Mark {
        guard !unrealized.contains(element) else { return .absent }
        guard !notPlanned.contains(element) else { return .notPlanned(reason: "") }

        let owners = [element] + (viewless.contains(element) ? [] : [tier].compactMap { $0 })
        for owner in owners {
            guard let record = records.first(where: { $0.owner == owner && $0.member == member }) else { continue }
            switch record.judgement {
            case .complete: return .complete
            case .partial(let missing): return .partial(missing: missing)
            case .notPlanned(let reason): return .notPlanned(reason: reason)
            }
        }
        return .absent
    }

    /// The records a declaration makes. A tier's record marks every element wearing the tier, so a member is
    /// recorded on its tier only where the host realizes it on every element it registers wearing that tier;
    /// realized on some of them, it is a record of each of those. The shared members and the acts belong to a
    /// contract, and are taken from it.
    public static func records(of declaration: HostDeclaration) -> [HostRecord] {
        let realization = declaration.realization
        var realizedOn: [Pair: Set<String>] = [:]
        for member in realization.members {
            realizedOn[Pair(owner: member.owner, member: member.member), default: []].insert(member.element)
        }

        var pairs: Set<Pair> = []
        for (pair, elements) in realizedOn {
            let wearers = realization.elements.filter { element in
                LibraryContracts.elements.first { $0.nodeType.name == element }?
                    .worn.contains { $0.name == pair.owner } == true
            }
            if elements.isSuperset(of: wearers) {
                pairs.insert(pair)
            } else {
                for element in elements { pairs.insert(Pair(owner: element, member: pair.member)) }
            }
        }
        for tier in declaration.tierMembers {
            pairs.insert(Pair(owner: tier.owner, member: tier.member))
        }

        return pairs
            .sorted { ($0.owner, $0.member) < ($1.owner, $1.member) }
            .map { .complete($0.owner, $0.member) }
    }

    /// Whether `element` wears `tier`, a contract other than its own.
    public static func wears(_ element: String, _ tier: String) -> Bool {
        element != tier && LibraryContracts.elements.first { $0.nodeType.name == element }?
            .worn.contains { $0.name == tier } == true
    }

    /// One owner and one member: a record, before it is one.
    private struct Pair: Hashable {
        let owner: String
        let member: String
    }
}
