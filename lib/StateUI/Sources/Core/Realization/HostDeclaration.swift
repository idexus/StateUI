// SPDX-FileCopyrightText: 2026 Paweł Krzywdziński and Contributors
// SPDX-License-Identifier: Apache-2.0

/// What a host declares, read off its own runtime: the elements it makes a view
/// for and, on each, the members it takes and the events it raises.
///
/// A declaration says presence, not who declares a member: a runtime does not
/// hold the contracts. `realization` answers that against the contracts, so an
/// owner is never written by hand.
@_spi(Host) public struct HostDeclaration: Equatable, Sendable {
    /// What one element's registration takes and raises.
    public struct Element: Equatable, Sendable {
        /// The members its view takes.
        public var members: Set<String>

        /// The events it raises.
        public var events: Set<String>

        /// An element declaring nothing, unless said.
        ///
        /// - Parameters:
        ///   - members: the members its view takes.
        ///   - events: the events it raises.
        public init(members: Set<String> = [], events: Set<String> = []) {
            self.members = members
            self.events = events
        }
    }

    /// Each element, by node type name.
    public var elements: [String: Element]

    /// What the host's shared machinery realizes on every element wearing the
    /// contract declaring it - margins, opacity, the gestures, the focus and frame
    /// reports - rather than one registration.
    public var shared: Element

    /// The acts this host performs, whichever element they are aimed at; each reaches
    /// whatever wears the contract declaring it.
    public var acts: Set<String>

    /// A declaration - nothing, unless said.
    ///
    /// - Parameters:
    ///   - elements: each element, by node type name.
    ///   - shared: what the shared machinery realizes on every wearer.
    ///   - acts: the acts the host performs.
    public init(
        elements: [String: Element] = [:],
        shared: Element = Element(),
        acts: Set<String> = []
    ) {
        self.elements = elements
        self.shared = shared
        self.acts = acts
    }

    /// What a runtime's registry declares: the library's elements it makes a view for, each with the
    /// members and events of its own, the shared machinery said once, and the acts it performs.
    ///
    /// An application's own elements are the application's to declare, so they are left out.
    ///
    /// - Parameters:
    ///   - realization: the registry's realization, the shared machinery spread over every wearer.
    ///   - shared: the names the shared machinery realizes and raises, `Registry.sharedNames`.
    ///   - acts: the names of the acts the host performs.
    public init(realization: HostRealization, shared: [String], acts: [String]) {
        let shared = Set(shared)
        let library = Set(LibraryContracts.elements.map { $0.nodeType.name })
        var byElement: [String: Set<String>] = [:]

        for element in realization.elements where library.contains(element) {
            byElement[element] = []
        }
        for member in realization.members where byElement[member.element] != nil {
            byElement[member.element, default: []].insert(member.member)
        }

        var elements: [String: Element] = [:]
        for (element, members) in byElement {
            elements[element] = HostDeclaration.split(members.subtracting(shared))
        }
        self.init(elements: elements, shared: HostDeclaration.split(shared), acts: Set(acts))
    }

    /// The export as a review reads it in the diff: one line per element, its members
    /// and then its events under it, an event told by the parentheses a handler is called with.
    public var text: String {
        func under(_ element: Element) -> [String] {
            element.members.sorted().map { "  \($0)" } + element.events.sorted().map { "  \($0)()" }
        }

        var lines: [String] = []
        for element in elements.keys.sorted() {
            lines.append(element)
            lines += under(elements[element] ?? Element())
        }
        lines.append("(every element)")
        lines += under(shared)
        lines.append("(acts)")
        lines += acts.sorted().map { "  \($0)()" }

        return lines.joined(separator: "\n") + "\n"
    }

    /// A declaration read back from its `text`, what a host's suite
    /// exports; nil for a text that is not one - a line out of place, an element
    /// said twice, or the shared machinery or the acts missing.
    ///
    /// - Parameter text: the text, as `text` writes it.
    public init?(text: String) {
        enum Section: Equatable { case element(String), shared, acts }

        var elements: [String: Element] = [:]
        var shared: Element?
        var acts: Set<String>?
        var section: Section?

        for whole in text.split(separator: "\n") {
            let line = whole.hasSuffix("\r") ? whole.dropLast() : whole

            guard line.hasPrefix("  ") else {
                switch String(line) {
                case "(every element)" where shared == nil:
                    shared = Element()
                    section = .shared
                case "(acts)" where shared != nil && acts == nil:
                    acts = []
                    section = .acts
                case let name where shared == nil && elements[name] == nil && !name.contains(" "):
                    elements[name] = Element()
                    section = .element(name)
                default:
                    return nil
                }
                continue
            }

            let said = line.dropFirst(2)
            let isEvent = said.hasSuffix("()")
            let name = String(isEvent ? said.dropLast(2) : said)

            guard !name.isEmpty, !name.contains(" ") else { return nil }

            switch section {
            case .element(let element)?:
                if isEvent { elements[element]?.events.insert(name) } else { elements[element]?.members.insert(name) }
            case .shared?:
                if isEvent { shared?.events.insert(name) } else { shared?.members.insert(name) }
            case .acts? where isEvent:
                acts?.insert(name)
            default:
                return nil
            }
        }

        guard let shared, let acts else { return nil }
        self.init(elements: elements, shared: shared, acts: acts)
    }

    /// Names split into what a view takes and what it raises, as the contracts declare each; a name no
    /// contract knows stays a member, where `undeclared` names it.
    private static func split(_ names: Set<String>) -> Element {
        Element(
            members: names.filter { !events.contains($0) },
            events: names.filter { events.contains($0) })
    }

    /// The name of every event the contracts declare.
    private static let events: Set<String> = {
        var events: Set<String> = []
        for contract in LibraryContracts.all {
            for case let member as any DeclaredMember in contract.members where member.facts.kind == .event {
                events.insert(member.name)
            }
        }
        return events
    }()

    /// What this declaration means against the contracts: the same members, each
    /// under the contract declaring it - the element's own, or the nearest tier it
    /// wears that declares a member of that name. A member no contract declares is
    /// left out rather than guessed at.
    public var realization: HostRealization {
        var members: Set<HostRealizedMember> = []
        var elements: Set<String> = []
        let sharedNames = shared.members.union(shared.events).union(acts)

        for (name, declared) in self.elements {
            elements.insert(name)

            guard let contract = LibraryContracts.elements.first(where: { $0.nodeType.name == name })
            else { continue }

            // The element's own, then every shared member whose contract this element wears.
            for member in declared.members.union(declared.events).union(sharedNames) {
                guard let owner = contract.worn.first(where: { owner in
                    owner.members.contains { $0.name == member }
                }) else { continue }

                members.insert(
                    HostRealizedMember(element: name, owner: owner.name, member: member))
            }
        }

        return HostRealization(elements: elements, members: members)
    }

    /// The shared members and the acts, each under the contract declaring it -
    /// answered from the contracts, so a tier worn only by elements this host
    /// registers nothing for is still counted.
    public var tierMembers: [(owner: String, member: String)] {
        var found: [(owner: String, member: String)] = []

        for member in shared.members.union(shared.events).union(acts).sorted() {
            guard let owner = LibraryContracts.all.first(where: { owner in
                owner.members.contains { $0.name == member }
            }) else { continue }

            found.append((owner: owner.name, member: member))
        }

        return found
    }

    /// What this declaration names that no contract declares: the element, and
    /// the member under it - a host and the contracts disagreeing, which is
    /// always a mistake on one side and never something to render.
    public var undeclared: [(element: String, member: String)] {
        var unknown: [(element: String, member: String)] = []

        // A shared member no contract declares is said under the empty element. Acts are
        // not listed: a host performs some of its own that no contract declares.
        // Design: docs/design/core/contracts.md#declarations
        for member in shared.members.union(shared.events).sorted()
        where !LibraryContracts.all.contains(where: { owner in
            owner.members.contains { $0.name == member }
        }) {
            unknown.append((element: "", member: member))
        }

        for (name, declared) in elements.sorted(by: { $0.key < $1.key }) {
            guard let contract = LibraryContracts.elements.first(where: { $0.nodeType.name == name })
            else {
                unknown.append((element: name, member: ""))
                continue
            }

            for member in declared.members.union(declared.events).sorted()
            where !contract.worn.contains(where: { owner in
                owner.members.contains { $0.name == member }
            }) {
                unknown.append((element: name, member: member))
            }
        }

        return unknown
    }
}
