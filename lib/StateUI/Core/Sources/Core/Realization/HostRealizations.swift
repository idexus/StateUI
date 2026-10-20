// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What the host told the core it realizes - nothing until it says.
@MainActor
enum HostRealizations {
    /// What the host said, replacing what it said before - at each start.
    static var current = HostRealization() {
        didSet {
            realizedMembers = nil
            honouredMembers = nil
            unhonouredSaid = [:]
        }
    }

    /// Where what the host judges it realizes, member by member, comes from - read when first asked: a host says
    /// it at each start, and building it costs.
    static var registerSource: () -> HostRegister? = { nil } {
        didSet {
            readRegister = nil
            honouredMembers = nil
            unhonouredSaid = [:]
        }
    }

    /// What the host judges it realizes, member by member - what the platform contract shows; nil before it says.
    static var register: HostRegister? {
        if let readRegister { return readRegister }
        let register = registerSource()
        readRegister = .some(register)
        return register
    }
    private static var readRegister: HostRegister??

    /// A member under the contract declaring it.
    private struct Owned: Hashable {
        let owner: KeyName
        let member: KeyName
    }

    /// Every member the host said it realizes, on any element - worked out when first asked, as a host says what
    /// it realizes at each start.
    private static var realizedMembers: Set<Owned>?
    private static var realized: Set<Owned> {
        if let realizedMembers { return realizedMembers }
        let realized = Set(current.members.map { Owned(owner: $0.owner, member: $0.member) })
        realizedMembers = realized
        return realized
    }

    /// The members the host realizes in full or in part by its register - each by its first record, on an element
    /// it does not leave out - else those it said it realizes; worked out when first asked.
    private static var honouredMembers: Set<Owned>?
    private static var honoured: Set<Owned> {
        if let honouredMembers { return honouredMembers }
        guard let register else { return realized }

        var judged: Set<Owned> = []
        var honoured: Set<Owned> = []
        for record in register.records {
            let owned = Owned(owner: KeyName(record.owner), member: KeyName(record.member))
            guard judged.insert(owned).inserted, case .complete? = register.judgement(ofElement: record.owner)
            else { continue }
            switch record.judgement {
            case .complete, .partial:
                honoured.insert(owned)
                // A tier's member recorded on one of its wearers is honoured by the tier too, in part at least.
                if let tier = register.declaring(record.member, on: record.owner), tier != record.owner {
                    honoured.insert(Owned(owner: KeyName(tier), member: owned.member))
                }
            case .notPlanned, .unrealized, .byApplication: break
            }
        }
        honouredMembers = honoured
        return honoured
    }

    /// Whether the host realizes `member` of the contract `owner` - in full or in part - by its register, else by
    /// what it said it realizes.
    /// Design: docs/design/core/contracts.md#what-a-platform-honours
    static func honours(_ member: KeyName, of owner: KeyName) -> Bool {
        honoured.contains(Owned(owner: owner, member: member))
    }

    /// Whether the host said it realizes `member` of the contract `owner`, on any element.
    static func realizes(_ member: KeyName, of owner: KeyName) -> Bool {
        realized.contains(Owned(owner: owner, member: member))
    }

    /// What to say about a node type described for the first time: nothing where the
    /// host realizes it or has said nothing, and otherwise that it does not, with the
    /// nearest realized names.
    /// Design: docs/design/core/contracts.md#unrealized-names
    static func unrealized(_ type: NodeType) -> String? {
        let realization = current

        guard realization != HostRealization(), type != .composed,
              !realization.elements.contains(type)
        else { return nil }

        return "the host realizes no `\(type.name)`"
            + nearMisses(type.name, among: Set(realization.elements.map(\.name))) + "."
    }

    /// What to say about `member` described on an element of `type`: that the host's register says it does not
    /// realize it there, or never will, with the register's reason - nothing where it realizes it, in part at least,
    /// where the register says nothing of it, and on an element the host realizes none of.
    /// Design: docs/design/core/contracts.md#unrealized-names
    static func unhonoured(_ member: KeyName, on type: NodeType) -> String? {
        let key = "\(type.name).\(member.name)"
        if let said = unhonouredSaid[key] { return said }
        var said: String?
        if let register, case .complete? = register.judgement(ofElement: type.name) {
            let tier = register.declaring(member.name, on: type.name)
            switch register.judgement(of: member.name, on: type.name, from: tier) {
            case .unrealized(let why)?: said = "`\(key)` is not realized on this host: \(Self.sentence(why))"
            case .notPlanned(let reason)?: said = "`\(key)` is never realized on this host: \(Self.sentence(reason))"
            default: break
            }
        }
        unhonouredSaid[key] = .some(said)
        return said
    }

    /// `words` ending as a sentence ends, once.
    private static func sentence(_ words: String) -> String {
        words.hasSuffix(".") ? words : words + "."
    }

    /// What `unhonoured` said of each element's member, worked out when first asked.
    private static var unhonouredSaid: [String: String?] = [:]

    /// What to say about an event of the application's a handler listens for:
    /// nothing where the host raises it, or has said nothing at all, and
    /// otherwise that it does not - with the events it raises nearest in name.
    static func unraised(owner: KeyName, event: KeyName) -> String? {
        let realization = current

        guard realization != HostRealization(), !realizes(event, of: owner) else { return nil }

        let raised = Set(realization.members.filter { $0.element == .application }.map(\.member.name))

        return "the host raises no `\(event.name)`" + nearMisses(event.name, among: raised)
            + ": the handler will not hear it."
    }

    /// " (nearest: `a`, `b`)" - the names at most a quarter of the name's
    /// length away, two edits at least, closest first, three at most - or
    /// nothing.
    private static func nearMisses(_ name: String, among names: Set<String>) -> String {
        let reach = max(2, name.count / 4)
        let near = names
            .map { (name: $0, edits: edits(from: name, to: $0)) }
            .filter { $0.edits <= reach }
            .sorted { ($0.edits, $0.name) < ($1.edits, $1.name) }
            .prefix(3)
            .map { "`\($0.name)`" }

        return near.isEmpty ? "" : " (nearest: " + near.joined(separator: ", ") + ")"
    }

    /// How many single-character edits turn one name into the other.
    private static func edits(from source: String, to target: String) -> Int {
        let from = Array(source)
        let to = Array(target)

        guard !from.isEmpty else { return to.count }
        guard !to.isEmpty else { return from.count }

        var row = Array(0...to.count)

        for i in 1...from.count {
            var diagonal = row[0]
            row[0] = i

            for j in 1...to.count {
                let above = row[j]
                row[j] = Swift.min(above + 1, row[j - 1] + 1, diagonal + (from[i - 1] == to[j - 1] ? 0 : 1))
                diagonal = above
            }
        }

        return row[to.count]
    }
}
