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
