// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host realizes of the contracts, member by member: its judgements written by hand, what its runtime says it
/// realizes, the elements it has none of and those its family never has. It decides whether a test of a member runs
/// on the host and what the test's verdict says; the mark itself is the test's.
/// Design: docs/design/contracts/dictionary.md#marks
@_spi(Host) public struct HostRegister: Sendable {
    /// Every judgement: the written ones first, then what the runtime realizes.
    public let records: [HostRecord]

    /// The elements the host realizes none of.
    public let unrealized: Set<NodeType>

    /// The elements the host's family will never have - each meeting the contract there - with why.
    public let notPlanned: [NodeType: String]

    /// The elements the host leaves to the application, which registers its own control for each - a map, where the
    /// platform has none of its own.
    public let byApplication: Set<NodeType>

    /// The elements every host presents with no view of their own - a span is a run of its label's words - which no
    /// tier's record reaches: only a member an element's own records name is realized there.
    public static let viewless: Set<NodeType> = [TextSpanContract.nodeType]

    /// A register of `records`, written before anything a runtime adds; the elements realized none of, never had -
    /// each with why - and left to the application.
    public init(
        records: [HostRecord], unrealized: [any ElementContract.Type] = [],
        notPlanned: [(any ElementContract.Type, reason: String)] = [], byApplication: [any ElementContract.Type] = []
    ) {
        self.init(
            records: records, unrealized: Set(unrealized.map { $0.nodeType }),
            notPlanned: Dictionary(notPlanned.map { ($0.0.nodeType, $0.reason) }) { first, _ in first },
            byApplication: Set(byApplication.map { $0.nodeType }))
    }

    private init(records: [HostRecord], unrealized: Set<NodeType>, notPlanned: [NodeType: String], byApplication: Set<NodeType>) {
        self.records = records
        self.unrealized = unrealized
        self.notPlanned = notPlanned
        self.byApplication = byApplication
    }

    /// This register with what the host's runtime realizes behind it. What is written comes first: a runtime says
    /// presence alone, where a written record may say what is missing, so a member the written half speaks for -
    /// on its owner, or on a tier the owner wears - is dropped from the runtime's records.
    public func and(_ runtime: [HostRecord]) -> HostRegister {
        let written = Set(records.map { "\($0.owner).\($0.member)" })
        let realized = runtime.filter { record in
            !written.contains("\(record.owner).\(record.member)")
                && !records.contains { $0.member == record.member && Self.wears(record.owner, $0.owner) }
        }
        return HostRegister(
            records: records + realized, unrealized: unrealized, notPlanned: notPlanned, byApplication: byApplication)
    }

    /// This register with a host's declaration of what its runtime realizes behind it.
    public func and(_ declaration: HostDeclaration) -> HostRegister {
        and(Self.records(of: declaration))
    }

    /// What the host's records say of `member` on `element`: the element's own record, else the record of the tier
    /// the member comes from; nil where the host does not realize it.
    public func judgement(of member: String, on element: String, from tier: String?) -> HostRecord.Judgement? {
        switch judgement(ofElement: element) {
        case nil: return nil
        case .notPlanned(let reason)?: return .notPlanned(reason: reason)
        case .byApplication?: return .byApplication
        default: break
        }

        let owners = [element] + (Self.viewless.contains { $0.name == element } ? [] : [tier].compactMap { $0 })
        for owner in owners {
            if let record = records.first(where: { $0.owner == owner && $0.member == member }) { return record.judgement }
        }
        return nil
    }

    /// The contract that declares `member` among what the library's element `element` wears, itself first - what a
    /// record of the register, written in words, is about.
    func declaring(_ member: String, on element: String) -> String? {
        LibraryContracts.elements.first { $0.nodeType.name == element }?
            .worn.first { $0.members.contains { $0.name == member } }?.name
    }

    /// What the host says of `element` itself: never, with why, where its family never has it; the application's
    /// where the application registers its own; made where it realizes it; nil where it realizes none of it.
    public func judgement(ofElement element: String) -> HostRecord.Judgement? {
        if let never = notPlanned.first(where: { $0.key.name == element }) { return .notPlanned(reason: never.value) }
        if byApplication.contains(where: { $0.name == element }) { return .byApplication }
        return unrealized.contains { $0.name == element } ? nil : .complete
    }

    /// Whether the host realizes `member` on `element` - in full or in part - so a test of it runs there.
    public func realizes(_ member: String, on element: String, from tier: String?) -> Bool {
        switch judgement(of: member, on: element, from: tier) {
        case .complete?, .partial?: true
        case .notPlanned?, .unrealized?, .byApplication?, nil: false
        }
    }

    /// What is wrong with the records a host wrote: one naming a member its owner does not wear, one written twice, a
    /// partial one saying nothing is missing, a never or an unrealized one saying no reason - and an element called
    /// both unrealized and never, both never and the application's, or both unrealized and the application's. Empty
    /// where nothing is.
    public var problems: [String] {
        var problems: [String] = []
        var seen: Set<String> = []
        for record in records {
            let named = "\(record.owner).\(record.member)"
            if !seen.insert(named).inserted { problems.append("\(named) is recorded twice") }
            if !Self.declares(record.member, owner: record.owner) {
                problems.append("\(named) names what no contract of \(record.owner) declares")
            }
            switch record.judgement {
            case .partial(let missing) where missing.isEmpty: problems.append("\(named) is partial and says nothing is missing")
            case .notPlanned(let reason) where reason.isEmpty: problems.append("\(named) is never and says no reason")
            case .unrealized(let why) where why.isEmpty: problems.append("\(named) is unrealized and says no reason")
            default: break
            }
        }
        for (element, reason) in notPlanned.sorted(by: { $0.key.name < $1.key.name }) {
            if reason.isEmpty { problems.append("\(element.name) is never and says no reason") }
            if unrealized.contains(element) { problems.append("\(element.name) is both unrealized and never") }
            if byApplication.contains(element) { problems.append("\(element.name) is both the application's and never") }
        }
        for element in byApplication.sorted(by: { $0.name < $1.name }) where unrealized.contains(element) {
            problems.append("\(element.name) is both unrealized and the application's")
        }
        return problems
    }

    /// Whether the contract named `owner` - an element's or a tier's, or one it wears - declares `member`.
    static func declares(_ member: String, owner: String) -> Bool {
        let contracts = LibraryContracts.tiers + LibraryContracts.elements.map { $0 as any Contract.Type }
        guard let contract = contracts.first(where: { $0.name == owner }) else { return false }
        return contract.worn.contains { $0.members.contains { $0.name == member } }
    }

    /// The records a declaration makes. A tier's record marks every element wearing the tier, so a member is
    /// recorded on its tier only where the host realizes it on every element it registers wearing that tier;
    /// realized on some of them, it is a record of each of those. The shared members and the acts belong to a
    /// contract, and are taken from it.
    public static func records(of declaration: HostDeclaration) -> [HostRecord] {
        let realization = declaration.realization
        var realizedOn: [Pair: Set<String>] = [:]
        for member in realization.members {
            realizedOn[Pair(owner: member.owner.name, member: member.member.name), default: []]
                .insert(member.element.name)
        }

        var pairs: Set<Pair> = []
        for (pair, elements) in realizedOn {
            let wearers = Set(realization.elements.map(\.name).filter { element in
                LibraryContracts.elements.first { $0.nodeType.name == element }?
                    .worn.contains { $0.name == pair.owner } == true
            })
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
            .map { HostRecord(owner: $0.owner, member: $0.member, judgement: .complete) }
    }

    /// The records of what a runtime realizes of the elements backends register - `contracts` - each on the element
    /// itself: every member their registrations take or raise, and every act of their contracts among `performed`.
    public static func records(
        ofBackends contracts: [any ElementContract.Type], in realization: HostRealization, performed: Set<String>
    ) -> [HostRecord] {
        let elements = Set(contracts.map { $0.nodeType })
        let realized = realization.members.filter { elements.contains($0.element) }
            .map { HostRecord(owner: $0.element.name, member: $0.member.name, judgement: .complete) }
        let acts = contracts.flatMap { contract in
            contract.members.filter { performed.contains($0.name) }.map { HostRecord.complete($0, on: contract) }
        }
        return (realized + acts).sorted { ($0.owner, $0.member) < ($1.owner, $1.member) }
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
